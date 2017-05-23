require 'yaml'
require 'json'
require 'zlib'
require 'digest'

module Esvg
  class SVG
    attr_accessor :svgs, :last_read, :svg_symbols

    CONFIG = {
      filename: 'svgs',
      class: 'svg-symbol',
      namespace: 'svg',
      core: true,
      namespace_before: true,
      optimize: false,
      gzip: false,
      fingerprint: true,
      throttle_read: 4,
      flatten: [],
      alias: {}
    }

    CONFIG_RAILS = {
      source: "app/assets/svgs",
      assets: "app/assets/javascripts",
      build: "public/javascripts",
      temp: "tmp"
    }

    def initialize(options={})
      config(options)

      @modules = {}
      @last_read = nil

      read_cache
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

        config[:filename] = File.basename(config[:filename], '.*')

        config[:pwd]      = File.expand_path Dir.pwd
        config[:source]   = File.expand_path config[:source] || config[:pwd]
        config[:build]    = File.expand_path config[:build]  || config[:pwd]
        config[:assets]   = File.expand_path config[:assets] || config[:pwd]

        config[:temp]     = config[:pwd] if config[:temp].nil?
        config[:temp]     = File.expand_path File.join(config[:temp], '.esvg-cache')

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

      puts "Read #{svgs.size} files from #{config[:source]}" if config[:print]

      if svgs.empty? && config[:print]
        puts "No svgs found at #{config[:source]}"
      end
    end

    def find_files
      files = Dir[File.join(config[:source], '**/*.svg')].uniq.sort
      @svg_symbols = {}

      # Remove deleted files from svg cache
      (svgs.keys - file_keys(files)).each { |f| svgs.delete(f) }

      dirs = {}

      files.each do |path|
        mtime = File.mtime(path).to_i
        key = file_key path
        dkey = dir_key path

        # Use cache if possible
        if svgs[key].nil? || svgs[key][:last_modified] != mtime
          svgs[key] = process_file(path, mtime)
        end

        # Name may have changed due to flatten config
        svgs[key][:name] = file_name(path)
        svgs[key][:attr][:name] = id(svgs[key][:name])

        dirs[dkey]           ||= {}
        (dirs[dkey][:files]  ||= []) << key

        if dirs[dkey][:last_modified].nil? || dirs[dkey][:last_modified] < mtime
          dirs[dkey][:last_modified] = mtime 
        end
      end

      dirs = sort(dirs)

      dirs.each do |dir, data|

        # overwrite cache if
        if svg_symbols[dir].nil?                                   || # No cache for this dir yet
          svg_symbols[dir][:last_modified] != data[:last_modified] || # New or updated file
          svg_symbols[dir][:files] != data[:files]                    # Changed files

          attributes = data[:files].map { |f| svgs[f][:attr] }
          mtimes = data[:files].map { |f| svgs[f][:last_modified] }.join

          svg_symbols[dir] = data.merge({
            name: dir,
            asset: File.basename(dir).start_with?('_'),
            version: config[:version] || Digest::MD5.hexdigest(mtimes)
          })

          svg_symbols[dir][:path] = write_path(dir)
        end
      end
      
      @svg_symbols = sort(@svg_symbols)
      @svgs = sort(@svgs)
    end

    def read_cache
      @svgs        = YAML.load(read_tmp '.svgs') || {}
    end

    def write_cache
      return if production?

      write_tmp '.svgs', sort(@svgs).to_yaml
    end

    def sort(hash)
      sorted = {}
      hash.sort.each do |h|
        sorted[h.first] = h.last
      end
      sorted
    end

    def embed_script(key=nil)
      if script = js(key)
        "<script>#{script}</script>"
      else
        ''
      end
    end

    def build_paths(keys=nil)
      build_files(keys).map { |s| File.basename(s[:path]) }
    end

    def build_files(keys=nil)
      valid_keys(keys).reject do |k|
        svg_symbols[k][:asset]
      end.map { |k| svg_symbols[k] }
    end

    def asset_files(keys=nil)
      valid_keys(keys).select do |k|
        svg_symbols[k][:asset]
      end.map { |k| svg_symbols[k] }
    end

    def process_file(path, mtime)
      content   = File.read(path)
      id        = id(file_key(path))
      size_attr = dimensions(content)

      {
        path: path,
        use: %Q{<use xlink:href="##{id}"/>},
        last_modified: mtime,
        attr: { id: id }.merge(size_attr),
        content: content
      }
    end

    def use(file, options={})
      if svg = find_svg(file, options[:fallback])

        if options[:color]
          options[:style] ||= ''
          options[:style] += "color:#{options[:color]};#{options[:style]}"
        end

        attr = {
          fill:   options[:fill],
          style:  options[:style],
          viewBox: svg[:attr][:viewBox],
          class: [config[:class], id(svg[:name]), options[:class]].compact.join(' ')
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

        use = %Q{<svg #{attributes(attr)}>#{svg[:use]}#{title(options)}#{desc(options)}#{options[:content]||''}</svg>}

        if Esvg.rails?
          use.html_safe
        else
          use
        end
      else
        if production?
          return ''
        else
          raise "no svg named '#{get_alias(file)}' exists at #{config[:source]}"
        end
      end
    end

    alias :svg_icon :use

    def dimensions(input)
      viewbox = input.scan(/<svg.+(viewBox=["'](.+?)["'])/).flatten.last
      if viewbox
        coords  = viewbox.split(' ')

        {
          viewBox: viewbox,
          width: coords[2].to_i - coords[0].to_i,
          height: coords[3].to_i - coords[1].to_i
        }
      else
        {}
      end
    end

    def attributes(hash)
      att = []
      hash.each do |key, value|
        att << %Q{#{key}="#{value}"} unless value.nil?
      end
      att.join(' ')
    end

    def exist?(name, fallback=nil)
      !find_svg(name, fallback).nil?
    end

    def find_svg(name, fallback=nil)
      name = get_alias dasherize(name)

      if svg = svgs.values.find { |v| v[:name] == name }
        svg
      elsif fallback
        find_svg(fallback)
      end
    end

    alias_method :exists?, :exist?

    def id(name)
      name = name_key(name)
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
      paths = write_files svg_symbols.values

      if config[:core]
        path = File.join config[:assets], "_esvg.js"
        write_file(path, js_core)
        paths << path
      end

      paths
    end

    def write_files(files)
      paths = []

      files.each do |file|
        content = js(file[:name])

        write_file(file[:path], content)
        puts "Writing #{file[:path]}" if config[:print]
        paths << file[:path]

        if !file[:asset] && gz = compress(file[:path])
          puts "Writing #{gz}" if config[:print]
          paths << gz
        end
      end

      write_cache

      paths
    end

    def symbols(keys)
      symbols = valid_keys(keys).map { |key|
        # Build on demand
        build_symbols(svg_symbols[key][:files])
      }.join.gsub(/\n/,'')

      %Q{<svg id="esvg-#{key_id(keys)}" version="1.1" style="height:0;position:absolute">#{symbols}</svg>}
    end

    def build_symbols(files)
      files.map { |file|
        if svgs[file][:optimized_at].nil? || svgs[file][:optimized_at] < svgs[file][:last_modified]
          svgs[file][:optimized_content] = optimize(svgs[file])
        end
        svgs[file][:optimized_content]
      }.join.gsub(/\n/,'')
    end

    def js(key)
      keys = valid_keys(key)
      return if keys.empty?

      script key_id(keys), symbols(keys).gsub('/n','').gsub("'"){"\\'"}
    end

    def script(id, symbols)
      %Q{(function(){

  function embed() {
    if (!document.querySelector('#esvg-#{id}')) {
      document.querySelector('body').insertAdjacentHTML('afterbegin', '#{symbols}')
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
      %Q{(function(){
  var names

  function attr( source, name ){
    if (typeof source == 'object')
      return name+'="'+source.getAttribute(name)+'" '
    else
      return name+'="'+source+'" ' }

  function dasherize( input ) {
    return input.replace(/[\\W,_]/g, '-').replace(/-{2,}/g, '-')
  }

  function svgName( name ) {
    #{if config[:namespace_before]
      %Q{return "#{config[:namespace]}-"+dasherize( name )}
    else
      %Q{return dasherize( name )+"-#{config[:namespace]}"}
    end}
  }

  function use( name, options ) {
    options = options || {}
    var id = dasherize( svgName( name ) )
    var symbol = svgs()[id]

    if ( symbol ) {
      var svg = document.createRange().createContextualFragment( '<svg><use xlink:href="#'+id+'"/></svg>' ).firstChild;
      svg.setAttribute( 'class', '#{config[:class]} '+id+' '+( options.classname || '' ).trim() )
      svg.setAttribute( 'viewBox', symbol.getAttribute( 'viewBox' ) )

      if ( !( options.width || options.height || options.scale ) ) {

        svg.setAttribute('width',  symbol.getAttribute('width'))
        svg.setAttribute('height', symbol.getAttribute('height'))

      } else {

        if ( options.width )  svg.setAttribute( 'width',  options.width )
        if ( options.height ) svg.setAttribute( 'height', options.height )
      }

      return svg
    } else {
      console.error('Cannot find "'+name+'" svg symbol. Ensure that svg scripts are loaded')
    }
  }

  function svgs(){
    if ( !names ) {
      names = {}
      for( var symbol of document.querySelectorAll( 'svg[id^=esvg] symbol' ) ) {
        names[symbol.getAttribute('name')] = symbol
      }
    }
    return names
  }

  var esvg = {
    svgs: svgs,
    use: use
  }

  // Handle Turbolinks page change events
  if ( window.Turbolinks ) {
    document.addEventListener( "turbolinks:load", function( event ) { names = null; esvg.svgs() })
  }

  if( typeof( module ) != 'undefined' ) { module.exports = esvg }
  else window.esvg = esvg

})()}
    end

    private

    def file_key(path)
      dasherize sub_path(path).sub('.svg','')
    end

    def dir_key(path)
      dir = File.dirname(flatten_path(path))

      # Flattened paths which should be treated as assets will use '_' as their dir key
      # - flatten: _foo - _foo/icon.svg will have a dirkey of _
      # - filename: _icons - treats all root or flattened files as assets
      if dir == '.' && ( sub_path(path).start_with?('_') || config[:filename].start_with?('_') )
        '_'
      else
        dir
      end
    end

    def file_name(path)
      dasherize flatten_path(path).sub('.svg','')
    end

    def sub_path(path)
      path.sub("#{config[:source]}/",'')
    end

    def flatten_path(path)
      sub_path(path).sub(Regexp.new(config[:flatten]), '')
    end

    def file_keys(paths)
      paths.flatten.map { |p| file_key(p) }
    end

    def name_key(key)
      if key == '_'  # Root level asset file
        "_#{config[:filename]}".sub(/_+/, '_')
      elsif key == '.'      # Root level build file
        config[:filename]
      else
        "#{key}"
      end
    end

    def write_path(key)
      name = name_key(key)

      if name.start_with?('_') # Is it an asset?
        File.join config[:assets], "#{name}.js"
      else # or a build file?

        # User doesn't want a fingerprinted build file
        if !config[:fingerprint]
          File.join config[:build], "#{name}.js"
        else
          File.join config[:build], "#{name}-#{version(key)}.js"
        end
      end
    end

    def svgo?
      !!(config[:optimize] && svgo_cmd)
    end

    def optimize(svg)
      svg[:optimized_content] = pre_optimize svg[:content]
      svg[:optimized_content] = sub_def_ids svg

      if svgo?
        response = Open3.capture3(%Q{#{} --disable=removeUselessDefs -s '#{svg[:content]}' -o -})
        svg[:optimized_content] = response[0] if response[2].success?
      end

      svg[:optimized_at] = Time.now.to_i
      svg[:optimized_content] = post_optimize svg
    end

    def pre_optimize(svg)
      reg = %w(xmlns xmlns:xlink xml:space version).map { |m| "#{m}=\".+?\"" }.join('|')
      svg.gsub(Regexp.new(reg), '')                           # Remove unwanted attributes
         .gsub(/<?.+\?>/,'').gsub(/<!.+?>/,'')                # Get rid of doctypes and comments
         .gsub(/style="([^"]*?)fill:(.+?);/m, 'fill="\2" style="\1')                   # Make fill a property instead of a style
         .gsub(/style="([^"]*?)fill-opacity:(.+?);/m, 'fill-opacity="\2" style="\1')   # Move fill-opacity a property instead of a style
         .gsub(/\n/, '')                                      # Remove endlines
         .gsub(/\s{2,}/, ' ')                                 # Remove whitespace
         .gsub(/>\s+</, '><')                                 # Remove whitespace between tags
         .gsub(/\s?fill="(#0{3,6}|black|rgba?\(0,0,0\))"/,'') # Strip black fill
    end

    def post_optimize(svg)
      svg[:optimized_content] = set_attributes(svg)
        .gsub(/<\/svg/,'</symbol')      # Replace svgs with symbols
        .gsub(/class="def-/,'id="def-') # Replace <def> classes with ids (classes are generated in sub_def_ids)
        .gsub(/\w+=""/,'')              # Remove empty attributes
    end

    def set_attributes(svg)
      svg[:attr].keys.each { |key| svg[:optimized_content].sub!(/ #{key}=".+?"/,'') }
      svg[:optimized_content].sub(/<svg/, "<symbol #{attributes(svg[:attr])}")
    end

    def svgo_cmd
      find_node_module('svgo')
    end
    
    # Scans <def> blocks for IDs
    # If urls(#id) are used, ensure these IDs are unique to this file
    # Only replace IDs if urls exist to avoid replacing defs
    # used in other svg files
    #
    def sub_def_ids(svg)
      content = svg[:optimized_content]
      name    = svg[:attr][:id]

      return content unless !!content.match(/<defs>/)

      content.scan(/<defs>.+<\/defs>/m).flatten.each do |defs|
        defs.scan(/id="(.+?)"/).flatten.uniq.each_with_index do |id, index|

          if content.match(/url\(##{id}\)/)
            new_id = "def-#{name}-#{index}"

            content = content.gsub(/id="#{id}"/, %Q{class="#{new_id}"})
                             .gsub(/url\(##{id}\)/, "url(##{new_id})" )
          else
            content = content.gsub(/id="#{id}"/, %Q{class="#{id}"})
          end
        end
      end

      content
    end

    def compress(file)
      return if !config[:gzip]

      mtime = File.mtime(file)
      gz_file = "#{file}.gz"

      return if (File.exist?(gz_file) && File.mtime(gz_file) >= mtime)

      File.open(gz_file, "wb") do |dest|
        gz = ::Zlib::GzipWriter.new(dest, Zlib::BEST_COMPRESSION)
        gz.mtime = mtime.to_i
        IO.copy_stream(open(file), gz)
        gz.close
      end

      File.utime(mtime, mtime, gz_file)

      gz_file
    end

    def write_tmp(name, content)
      path = File.join(config[:temp], name)
      FileUtils.mkdir_p(File.dirname(path))
      write_file path, content
      path
    end

    def read_tmp(name)
      path = File.join(config[:temp], name)
      if File.exist? path
        File.read path
      else
        ''
      end
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
        (key == '.') ? 'symbols' : id(key)
      end.join('-')
    end

    # Determine if an NPM module is installed by checking paths with `npm bin`
    # Returns path to binary if installed
    def find_node_module(cmd)
      require 'open3'

      return @modules[cmd] unless @modules[cmd].nil?

      @modules[cmd] = begin
        local = "$(npm bin)/#{cmd}"
        global = "$(npm -g bin)/#{cmd}"

        if Open3.capture3(local)[2].success?
          local
        elsif Open3.capture3(global)[2].success?
          global
        else
          false
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
      if keys.nil? || keys.empty?
        svg_symbols.keys
      else
        keys = [keys].flatten.map { |k| dasherize k }
        svg_symbols.keys.select { |k| keys.include? dasherize(k) }
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

    def production?
      config[:produciton] || if Esvg.rails?
        Rails.env.production?
      end
    end
  end
end
