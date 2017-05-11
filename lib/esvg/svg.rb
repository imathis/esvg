require 'yaml'
require 'json'
require 'zlib'

module Esvg
  class SVG
    attr_accessor :svgs, :last_read, :svg_groups, :svg_symbols

    CONFIG = {
      filename: 'svgs',
      base_class: 'svg-graphic',
      namespace: 'svg',
      namespace_before: true,
      optimize: false,
      compress: false,
      throttle_read: 4,
      flatten: [],
      alias: {}
    }

    CONFIG_RAILS = {
      source: "app/assets/svgs",
      assets: "app/assets/javascripts",
      build: "public/assets",
      tmp_path: "tmp"
    }

    def initialize(options={})
      config(options)

      @modules = {}
      @last_read = nil
      @svgs = {}
      @svg_groups = {}
      @svg_symbols = {}
      @last_modified = {}

      read_files
    end

    def config(options={})
      @config ||= begin
        paths = [options[:config_file], 'config/esvg.yml', 'esvg.yml'].compact

        config = CONFIG.dup

        if Esvg.rails? || options[:rails]
          config.merge!(CONFIG_RAILS)
        end

        if path = paths.select{ |p| File.exist?(p)}.first
          config.merge!(symbolize_keys(YAML.load(File.read(path) || {})))
        end

        config.merge!(options)

        config[:pwd]      = File.expand_path Dir.pwd
        config[:source]   = File.expand_path config[:source] || Dir.pwd
        config[:build]    = File.expand_path config[:build]  || Dir.pwd
        config[:assets]   = File.expand_path config[:assets] || Dir.pwd

        config[:aliases] = load_aliases(config[:alias])
        config[:flatten] = [config[:flatten]].flatten.map { |dir| File.join(dir, '/') }.join('|')

        config
      end
    end

    def read_files
      if !@last_read.nil? && (Time.now.to_i - @last_read) < config[:throttle_read]
        return
      end

      # Get a list of svg files and modification times
      #
      find_files

      @last_read = Time.now.to_i

      puts "Read #{svgs.size} files from #{config[:source]}" if config[:cli]

      if svgs.empty? && config[:cli]
        puts "No svgs found at #{config[:source]}"
      end
    end

    def find_files
      files = Dir[File.join(config[:source], '**/*.svg')].uniq

      files.each do |path|

        mtime = File.mtime path
        key = file_key path
        dkey = dir_key path

        # Use cache if possible
        if svgs[key].nil? || svgs[key][:last_modified] != mtime
          svgs[key] = process_file(path, mtime, key)
        end

        (svg_groups[dkey]    ||= []).push key
        (@last_modified[dkey] ||= []).push mtime
      end

      svg_groups.each do |key, files|
        symbols = files.map { |file| svgs[file][:content] }.join

        last_change = @last_modified[key].sort.last

        if svg_symbols[key].nil? || svg_symbols[key][:last_modified] != last_change
          svg_symbols[key] = {
            last_modified: last_change,
            symbols: optimize(symbols).gsub(/class=/,'id=').gsub(/svg/,'symbol'),
            version: config[:version] || Digest::MD5.hexdigest(symbols)
          }
        end
      end

      # Remove deleted files from svg cache
      #
      (svgs.keys - files.map {|file| file_key(file) }).each do |f|
        svgs.delete(f)
      end
    end

    def embed_script(key=nil)
      script = js(key)
      "<script>#{script}</script>" if script
    end

    def build_paths(keys=nil)
      valid_keys(keys).map do |k|
        k = File.basename(write_path(k))
        if !k.start_with?('_')
          k
        end
      end.compact
    end

    def process_file(file, mtime, name)
      content   = File.read(file)
      classname = classname(name)
      size_attr = dimensions(content)

      svg = {
        name: name,
        use: %Q{<use xlink:href="##{classname}"/>},
        last_modified: mtime,
        attr: { classname: classname }.merge(dimensions(content))
      }

      # Add attributes
      svg[:content] = prep_svg(content, svg[:attr])

      svg
    end

    def use(file, options={})
      name = get_alias dasherize(file)

      if !exist?(name)
        if fallback = options.delete(:fallback)
          use(fallback, options)
        else
          if Esvg.rails? && Rails.env.production?
            return ''
          else
            raise "no svg named '#{get_alias(file)}' exists at #{config[:source]}"
          end
        end
      else

        svg = svgs[name]

        if options[:color]
          options[:style] ||= ''
          options[:style] += "color:#{options[:color]};#{options[:style]}"
        end

        attr = {
          fill:   options[:fill],
          style:  options[:style],
          viewbox: svg[:attr][:viewbox],
          classname: [config[:base_class], svg[:attr][:classname], options[:class]].compact.join(' ')
        }

        # If user doesn't pass a size or set scale: true
        if !(options[:width] || options[:height] || options[:scale])

          # default to svg dimensions
          attr[:width]  = svg[:attr][:width]
          attr[:height] = svg[:attr][:height]
        else

          # Add sizes (nil options will be stripped)
          attr[:width]  = options[:width]
          attr[:height] = options[:height]
        end

        use = %Q{<svg #{attributes(attr)}>#{svg[:use]}#{title(options)}#{desc(options)}</svg>}

        if Esvg.rails?
          use.html_safe
        else
          use
        end
      end
    end

    alias :svg_icon :use

    def dimensions(input)
      viewbox = input.scan(/<svg.+(viewBox=["'](.+?)["'])/).flatten.last
      coords  = viewbox.split(' ')

      {
        viewbox: viewbox,
        width: coords[2].to_i - coords[0].to_i,
        height: coords[3].to_i - coords[1].to_i
      }
    end

    def attributes(hash)
      att = []
      hash.each do |key, value|
        att << %Q{#{key}="#{value}"} unless value.nil?
      end
      att.join(' ')
    end

    def exist?(name)
      name = get_alias(name)
      !svgs[name].nil?
    end

    alias_method :exists?, :exist?

    def classname(name)
      if config[:namespace_before]
        dasherize "#{config[:namespace]}-#{name}"
      else
        dasherize "#{name}-#{config[:namespace]}"
      end
    end

    def dasherize(input)
      input.gsub(/[\W,_]/, '-').sub(/^-/,'').gsub(/-{2,}/, '-')
    end

    def title(options)
      if options[:title]
        "<title>#{options[:title]}</title>"
      else
        ''
      end
    end

    def desc(options)
      if options[:desc]
        "<desc>#{options[:desc]}</desc>"
      else
        ''
      end
    end

    def version(key)
      svg_symbols[key][:version]
    end

    def build
      paths = []
      svg_groups.keys.each do |key|
        path = write_path(key)

        write_file(path, js(key))
        puts "Writing #{path}"

        if gz = compress(path)
          puts "Writing #{gz}"
        end

      end
    end

    def symbols(keys)
      symbols = valid_keys(keys).map { |key|
        svg_symbols[key][:symbols]
      }.join

      %Q{<svg id="esvg-#{key_id(keys)}" version="1.1" style="height:0;position:absolute">#{symbols}</svg>}
    end

    def js(key)
      keys = valid_keys(key)
      return if keys.empty?

      embed_symbols = symbols(keys).gsub(/\n/,'').gsub("'"){"\\'"}

      %Q{(function(){

  function embed() {
    if (!document.querySelector('#esvg-#{key_id(keys)}')) {
      document.querySelector('body').insertAdjacentHTML('afterbegin', '#{embed_symbols}')
    }
  }

  // If DOM is already ready, embed SVGs
  if (document.readyState == 'interactive') { embed() }

  // Handle Turbolinks page change events
  if ( window.Turbolinks ) {
    document.addEventListener("turbolinks:load", function(event) { embed() })
  }

  // Handle standard DOM ready events
  document.addEventListener("DOMContentLoaded", function(event) { embed() })
})()}
    end

    def js_core
      %Q{var esvg = {
  icon: function(name, classnames) {
    var svgName = this.iconName(name)
    var element = document.querySelector('#'+svgName)

    if (element) {
      return '<svg class="#{config[:base_class]} '+svgName+' '+(classnames || '')+'" '+this.dimensions(element)+'><use xlink:href="#'+svgName+'"/></svg>'
    } else {
      console.error('File not found: "'+name+'.svg" at #{log_path(File.join(config[:source],''))}/')
    }
  },
  iconName: function(name) {
    var before = #{config[:namespace_before]}
    if (before) {
      return "#{config[:namespace]}-"+this.dasherize(name)
    } else {
      return name+"-#{config[:namespace]}"
    }
  },
  dimensions: function(el) {
    return 'viewBox="'+el.getAttribute('viewBox')+'" width="'+el.getAttribute('width')+'" height="'+el.getAttribute('height')+'"'
  },
  dasherize: function(input) {
    return input.replace(/[\W,_]/g, '-').replace(/-{2,}/g, '-')
  },
  aliases: #{config[:aliases].to_json},
  alias: function(name) {
    var aliased = this.aliases[name]
    if (typeof(aliased) != "undefined") {
      return aliased
    } else {
      return name
    }
  }
}

// Work with module exports:
if(typeof(module) != 'undefined') { module.exports = esvg }
}
    end

    private

    def dir_key(path)
      dir = File.dirname(flatten_path(path))

      # Flattened paths which should be treated as assets will use '_' as their dir key
      if dir == '.' && sub_path(path).start_with?('_')
        '_'
      else
        dir
      end
    end

    def sub_path(path)
      path.sub("#{config[:source]}/",'')
    end

    def flatten_path(path)
      sub_path(path).sub(Regexp.new(config[:flatten]), '')
    end

    def file_key(path)
      dasherize flatten_path(path).sub('.svg', '')
    end

    def write_path(key)

      name = if key == '_'
        "_#{config[:filename]}"
      elsif key == '.'
        config[:filename]
      else
        "#{key}"
      end

      # Is it an asset, or a build file
      if key.start_with?('_')
        File.join config[:assets], "#{name}.js"
      else
        File.join config[:build], "#{name}-#{version(key)}.js"
      end
    end

    def prep_svg(content, attr)
      content = content.gsub(/<?.+\?>/,'').gsub(/<!.+?>/,'') # get rid of doctypes and comments
             .gsub(/<svg.+?>/, %Q{<svg #{attributes(attr)}>})  # Remove clutter from svg declaration
             .gsub(/\n/, '')                       # Remove endlines
             .gsub(/\s{2,}/, ' ')                  # Remove whitespace
             .gsub(/>\s+</, '><')                  # Remove whitespace between tags
             .gsub(/\s?fill="(#0{3,6}|black|rgba?\(0,0,0\))"/,'')      # Strip black fill
             .gsub(/style="([^"]*?)fill:(.+?);/m, 'fill="\2" style="\1')                   # Make fill a property instead of a style
             .gsub(/style="([^"]*?)fill-opacity:(.+?);/m, 'fill-opacity="\2" style="\1')   # Move fill-opacity a property instead of a style

      sub_def_ids(content, attr[:classname])
    end

    # Scans <def> blocks for IDs
    # If urls(#id) are used, ensure these IDs are unique to this file
    # Only replace IDs if urls exist to avoid replacing defs
    # used in other svg files
    #
    def sub_def_ids(content, classname)
      return content unless !!content.match(/<defs>/)

      content.scan(/<defs>.+<\/defs>/m).flatten.each do |defs|
        defs.scan(/id="(.+?)"/).flatten.uniq.each_with_index do |id, index|

          if content.match(/url\(##{id}\)/)
            new_id = "#{classname}-ref#{index}"

            content = content.gsub(/id="#{id}"/, %Q{class="#{new_id}"})
                             .gsub(/url\(##{id}\)/, "url(##{new_id})" )
          else
            content = content.gsub(/id="#{id}"/, %Q{class="#{id}"})
          end
        end
      end

      content
    end

    def optimize(svg)

      if config[:optimize] && svgo_path = find_node_module('svgo')
        path = write_svg(svg)
        command = "#{svgo_path} --disable=removeUselessDefs '#{path}' -o -"
        svg = `#{command}`
        FileUtils.rm(path)
      end

      svg
    end

    def compress(file)
      mtime = File.mtime(file)
      gz_file = "#{file}.gz"
      return if !config[:compress] || (File.exist?(gz_file) && File.mtime(gz_file) >= mtime)

      File.open(gz_file, "wb") do |dest|
        gz = ::Zlib::GzipWriter.new(dest, Zlib::BEST_COMPRESSION)
        gz.mtime = mtime.to_i
        IO.copy_stream(open(file), gz)
        gz.close
      end

      File.utime(mtime, mtime, gz_file)

      gz_file
    end

    def write_svg(svg)
      path = File.join((config[:tmp_path] || config[:build]), '.esvg-tmp')
      write_file path, svg
      path
    end

    def log_path(path)
      File.expand_path(path).sub(config[:pwd], '').sub(/^\//,'')
    end

    def write_file(path, contents)
      FileUtils.mkdir_p(File.expand_path(File.dirname(path)))
      File.open(path, 'w') do |io|
        io.write(contents)
      end
    end

    def key_id(keys)
      keys.map do |key|
        (key == '.') ? 'symbols' : classname(key)
      end.join('-')
    end

    # Determine if an NPM module is installed by checking paths with `npm bin`
    # Returns path to binary if installed
    def find_node_module(cmd)
      require 'open3'
      @modules[cmd] ||= begin

        local = "$(npm bin)/#{cmd}"
        global = "$(npm -g bin)/#{cmd}"
        
        if Open3.capture3(local)[2].success?
          local
        elsif Open3.capture3(global)[2].success?
          global
        end

      end
    end

    def symbolize_keys(hash)
      h = {}
      hash.each {|k,v| h[k.to_sym] = v }
      h
    end

    # Return non-empty key names for groups of svgs
    def valid_keys(keys)
      if keys.nil?
        svg_groups.keys
      else
        keys = [keys].flatten.map { |k| dasherize k }
        svg_groups.keys.select { |k| keys.include? dasherize(k) }
      end
    end

    # Load aliases from configuration.
    #  returns a hash of aliasees mapped to a name.
    #  Converts configuration YAML:
    #    alias:
    #      foo: bar
    #      baz: zip, zop
    #  To output:
    #    { :bar => "foo", :zip => "baz", :zop => "baz" }
    #
    def load_aliases(aliases)
      a = {}
      aliases.each do |name,alternates|
        alternates.split(',').each do |val|
          a[dasherize(val.strip).to_sym] = dasherize(name.to_s)
        end
      end
      a
    end

    def get_alias(name)
      config[:aliases][dasherize(name).to_sym] || name
    end


  end
end
