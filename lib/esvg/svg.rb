require 'yaml'
require 'json'

module Esvg
  class SVG
    attr_accessor :files, :svgs, :last_read, :svg_cache

    CONFIG = {
      base_class: 'svg-icon',
      namespace: 'icon',
      optimize: false,
      namespace_before: true,
      verbose: false,
      format: 'js',
      throttle_read: 4,
      flatten: [],
      alias: {}
    }

    CONFIG_RAILS = {
      path: "app/assets/svgs",
      js_path: "public/_svgs.js",
      js_build_dir: "public/assets"
    }

    def initialize(options={})
      config(options)

      @last_read = nil
      @svg_cache = {}

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
        
        config[:path] ||= Dir.pwd
        config[:output_path] ||= Dir.pwd

        if config[:cli]
          config[:path] = File.expand_path(config[:path])
          config[:output_path] = File.expand_path(config[:output_path])
        end

        config[:js_path]        ||= File.join(config[:output_path], 'svgs.js')
        config[:js_core_path]   ||= config[:js_path].sub(/[^\/]+?\./, '_esvg-core.') unless config[:js_core_path] == false
        config[:html_path]      ||= File.join(config[:output_path], 'esvg.html')
        config.delete(:output_path)
        config[:aliases] = load_aliases(config[:alias])
        config[:flatten] = [config[:flatten]].flatten.map { |dir| File.join(dir, '/') }.join('|')

        config
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

    def embed_script(key)
      "<script>#{embed_js(key)}</script>"
    end

    def embed_js(key)
      js(key || '.')
    end

    def embed(key)
      return if files.empty?
      output = if config[:format] == "html"
        html(key)
      elsif config[:format] == "js"
        js(key)
      end

      if Esvg.rails?
        output.html_safe
      else
        output
      end
    end

    def read_files
      if !@last_read.nil? && (Time.now.to_i - @last_read) < config[:throttle_read]
        return
      end

      @files = {}

      # Get a list of svg files and modification times
      #
      find_files.each do |f|
        files[f] = File.mtime(f)
      end

      @last_read = Time.now.to_i

      puts "Read #{files.size} files from #{config[:path]}" if config[:cli]

      process_files

      if files.empty? && config[:cli]
        puts "No svgs found at #{config[:path]}"
      end
    end

    # Add new svgs, update modified svgs, remove deleted svgs
    #
    def process_files
      @svgs = {}

      files.each do |path, mtime|
        key = file_key( path )

        if svg_cache[key].nil? || svg_cache[key][:last_modified] != mtime
          svg_cache[key] = process_file(path, mtime, key)
        end

        svgs[File.dirname( flatten_path( path ) )] ||= {}
        svgs[File.dirname( flatten_path( path ) )][key] = svg_cache[key]
      end

      # Remove deleted svgs
      #
      (svg_cache.keys - files.keys.map {|file| file_key(file) }).each do |f|
        svg_cache.delete(f)
      end
    end

    def build_paths
      build_keys = svgs.keys.reject do |key|
        key == '.' ||
        key.match(/^_/) ||
        config[:flatten].include?(key)
      end

      build_keys.map { | key | File.expand_path(build_path(key)) }
    end

    def flatten_path(path)
      root_path = File.expand_path(config[:path])

      path.sub("#{root_path}/",'').sub('.svg', '')
          .sub(Regexp.new(config[:flatten]), '')
    end

    def file_key(path)
      dasherize flatten_path(path)
    end

    def process_file(file, mtime, name)
      content = File.read(file).gsub(/<?.+\?>/,'').gsub(/<!.+?>/,'')
      {
        name: name,
        content: content,
        use: use_svg(name, content),
        last_modified: mtime
      }
    end

    def use_svg(file, content)
      name = classname get_alias(file)
      viewbox = content.scan(/<svg.+(viewBox=["'](.+?)["'])/).flatten.first
      %Q{<svg class="#{config[:base_class]} #{name}" #{viewbox}><use xlink:href="##{name}"/></svg>}
    end

    def svg_icon(file, options={})
      name = dasherize file

      if !exist?(name)
        if fallback = options.delete(:fallback)
          svg_icon(fallback, options)
        else
          if Esvg.rails? && Rails.env.production?
            return ''
          else
            raise "no svg named '#{get_alias(file)}' exists at #{config[:path]}"
          end
        end
      else

        use = use_icon(name)
        use = use.sub(/class="(.+?)"/, 'class="\1 '+options[:class]+'"') if options[:class]

        if options[:color]
          options[:style] ||= ''
          options[:style] += ";color:#{options[:color]};"
        end

        use = add_attribute(use, 'style', options[:style], ';')
        use = add_attribute(use, 'fill', options[:fill])
        use = add_attribute(use, 'height', options[:height])
        use = add_attribute(use, 'width', options[:width])

        use = use.sub(/><\/svg/, ">#{title(options)}#{desc(options)}</svg")

        if Esvg.rails?
          use.html_safe
        else
          use
        end
      end
    end

    alias :use :svg_icon

    def add_attribute(tag, attr, content=nil, append=false)
      return tag if content.nil?
      content = content.to_s
      if tag.match(/#{attr}/)
        if append
          tag.sub(/#{attr}="(.+?)"/, attr+'="\1'+append+content+'"')
        else
          tag.sub(/#{attr}=".+?"/, attr+'="'+content+'"')
        end
      else
        tag.sub(/><use/, %Q{ #{attr}="#{content}"><use})
      end
    end

    def dimensions(input)
      dimension = input.scan(/<svg.+(viewBox=["'](.+?)["'])/).flatten
      viewbox = dimension.first
      coords = dimension.last.split(' ')

      width = coords[2].to_i - coords[0].to_i
      height = coords[3].to_i - coords[1].to_i
      %Q{#{viewbox} width="#{width}" height="#{height}"}
    end

    def use_icon(name)
      name = get_alias(name)
      svg_cache[name][:use]
    end

    def exist?(name)
      name = get_alias(name)
      !svg_cache[name].nil?
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

    def find_files
      path = File.expand_path(File.join(config[:path], '**/*.svg'))
      Dir[path].uniq
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

    def build
      paths = []
      svgs.each do |key, files|
        unless key.start_with?('_')

          content = js(key)
          version = config[:js_build_version] || Digest::MD5.hexdigest(content)

          key = File.basename(config[:js_path], '.*') if key == "."
          dir = config[:js_build_dir] || File.dirname(config[:js_path])
          path = File.join(dir, "#{key}-#{version}.js")

          if !File.exist?(path)
            write_file(path, content)
            puts "Writing #{path}" 
          end

          if gz = compress(path)
            puts "Writing #{gz}" 
          end
        end
      end
    end

    def compress(file)
      mtime = File.mtime(file)
      gz_file = "#{file}.gz"
      return if File.exist?(gz_file) && File.mtime(gz_file) >= mtime

      File.open(gz_file, "wb") do |dest|
        gz = Zlib::GzipWriter.new(dest, Zlib::BEST_COMPRESSION)
        gz.mtime = mtime.to_i
        IO.copy_stream(open(file), gz)
        gz.close
      end

      File.utime(mtime, mtime, gz_file)

      gz_file
    end

    def write
      return if @files.empty?
      write_paths = case config[:format]
      when "html"
        write_html
      when "js"
        write_js
      end

      write_paths.each do |path|
        puts "Written to #{log_path path}" if config[:cli]
      end

      write_paths
    end

    def log_path(path)
      File.expand_path(path).sub(File.expand_path(Dir.pwd), '').sub(/^\//,'')
    end

    def write_svg(svg)
      path = File.join((config[:tmp_path] || config[:path]), '.esvg-tmp')
      write_file path, svg
      path
    end

    def write_js
      paths = []

      unless config[:js_core_path] == false
        path = config[:js_core_path]
        write_file path, js_core

        paths.push path
      end

      svgs.each do |key, files|
        path = write_path(:js_path, key)
        write_file path, js(key)
        paths.push path
      end

      paths
    end

    def write_html
      paths = []

      svgs.each do |key, files|
        path = write_path(:html_path, key)
        write_file path, html(key)
        paths.push path
      end

      paths
    end 

    def write_file(path, contents)
      FileUtils.mkdir_p(File.expand_path(File.dirname(path)))
      File.open(path, 'w') do |io|
        io.write(contents)
      end
    end

    def build_path(key)
      dir = config[:js_build_dir] || File.dirname(config[:js_path])
           
      if config[:js_build_version]
        key = "#{key}-#{config[:js_build_version]}"
      end

      File.join(dir, key+'.js')
    end

    def write_path(type, key)
      # Write root svgs
      return config[type] if key == "."

      if !key.start_with?('_') && type.to_s.start_with?('js')
        build_path(key)
      else
        config[type].sub(/[^\/]+?\./, key+'.')
      end
    end

    # Scans <def> blocks for IDs
    # If urls(#id) are used, ensure these IDs are unique to this file
    # Only replace IDs if urls exist to avoid replacing defs
    # used in other svg files
    #
    def sub_def_ids(file, content)
      return content unless !!content.match(/<defs>/)

      content.scan(/<defs>.+<\/defs>/m).flatten.each do |defs|
        defs.scan(/id="(.+?)"/).flatten.uniq.each_with_index do |id, index|

          if content.match(/url\(##{id}\)/)
            new_id = "#{classname(file)}-ref#{index}"

            content = content.gsub(/id="#{id}"/, %Q{class="#{new_id}"})
                             .gsub(/url\(##{id}\)/, "url(##{new_id})" )
          else
            content = content.gsub(/id="#{id}"/, %Q{class="#{id}"})
          end
        end
      end

      content
    end

    def prep_svg(file, content)
      content = content.gsub(/<svg.+?>/, %Q{<svg class="#{classname(file)}" #{dimensions(content)}>})  # convert svg to symbols
             .gsub(/\n/, '')                 # Remove endlines
             .gsub(/\s{2,}/, ' ')            # Remove whitespace
             .gsub(/>\s+</, '><')            # Remove whitespace between tags
             .gsub(/\s?fill="(#0{3,6}|black|rgba?\(0,0,0\))"/,'')      # Strip black fill
             .gsub(/style="([^"]*?)fill:(.+?);/m, 'fill="\2" style="\1')                   # Make fill a property instead of a style
             .gsub(/style="([^"]*?)fill-opacity:(.+?);/m, 'fill-opacity="\2" style="\1')   # Move fill-opacity a property instead of a style

      sub_def_ids(file, content)
    end

    def optimize(svg)
      if config[:optimize] && svgo_path = find_node_module('svgo')
        path = write_svg(svg)
        svg = `#{svgo_path} --disable=removeUselessDefs '#{path}' -o -`
        FileUtils.rm(path)
      end

      svg
    end

    def valid_keys(keys)
      [keys].flatten.reject { |k| svgs[k].empty? }.uniq
    end

    def html(keys)
      keys = valid_keys(keys)

      return "" if keys.empty?
      symbols = []

      keys.each do |key|
        svgs[key].each do |name, data|
          symbols << prep_svg(name, data[:content])
        end
      end

      symbols = optimize(symbols.join).gsub(/class=/,'id=').gsub(/svg/,'symbol')

      %Q{<svg id="esvg-#{key_id(keys)}" version="1.1" style="height:0;position:absolute">#{symbols}</svg>}
    end

    def key_id(keys)
      keys.map do |key|
        (key == '.') ? 'symbols' : classname(key) 
      end.join('-')
    end

    def svg_to_js(keys)
      html(keys).gsub(/\n/,'').gsub("'"){"\\'"}
    end

    def js_core
      %Q{var esvg = {
  icon: function(name, classnames) {
    var svgName = this.iconName(name)
    var element = document.querySelector('#'+svgName)

    if (element) {
      return '<svg class="#{config[:base_class]} '+svgName+' '+(classnames || '')+'" '+this.dimensions(element)+'><use xlink:href="#'+svgName+'"/></svg>'
    } else {
      console.error('File not found: "'+name+'.svg" at #{log_path(File.join(config[:path],''))}/')
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

    def js(key)
      keys = [key].flatten.reject { |k| svgs[k].empty? }
      return "" if keys.empty?
      %Q{(function(){

  function embed() {
    if (!document.querySelector('#esvg-#{key_id(keys)}')) {
      document.querySelector('body').insertAdjacentHTML('afterbegin', '#{svg_to_js(keys)}')
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

    def find_node_module(cmd)
      require 'open3'

      response = Open3.capture3("npm ls #{cmd}")

      # Check for error
      if response[1].empty?
        "$(npm bin)/#{cmd}"

      # Attempt global module path
      elsif Open3.capture3("npm ls -g #{cmd}")[1].empty?
        cmd
      end
    end

    def symbolize_keys(hash)
      h = {}
      hash.each {|k,v| h[k.to_sym] = v }
      h
    end

  end
end
