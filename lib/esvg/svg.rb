require 'yaml'

module Esvg
  class SVG
    attr_accessor :files, :svgs

    CONFIG = {
      path: Dir.pwd,
      base_class: 'svg-icon',
      namespace: 'icon',
      optimize: false,
      npm_path: false,
      namespace_before: true,
      font_size: '1em',
      output_path: Dir.pwd,
      verbose: false,
      format: 'js',
      alias: {}
    }

    CONFIG_RAILS = {
      path: "app/assets/esvg"
    }

    def initialize(options={})
      config(options)

      @svgo = nil
      @svgs = {}

      read_files
    end

    def config(options={})
      @config ||= begin
        paths = [options[:config_file], 'config/esvg.yml', 'esvg.yml'].compact

        config = CONFIG
        config.merge!(CONFIG_RAILS) if Esvg.rails?

        if path = paths.select{ |p| File.exist?(p)}.first
          config.merge!(symbolize_keys(YAML.load(File.read(path) || {})))
        end

        config.merge!(options)

        if config[:cli]
          config[:path] = File.expand_path(config[:path])
          config[:output_path] = File.expand_path(config[:output_path])
        end

        config[:js_path]   ||= File.join(config[:output_path], 'esvg.js')
        config[:css_path]  ||= File.join(config[:output_path], 'esvg.css')
        config[:html_path] ||= File.join(config[:output_path], 'esvg.html')
        config.delete(:output_path)
        config[:aliases] = load_aliases(config[:alias])

        config
      end
    end

    def load_aliases(aliases)
      a = {}
      aliases.each do |k,v|
        v.split(',').each do |val|
          a[dasherize(val.strip)] = dasherize(k.to_s)
        end
      end
      a
    end

    def get_alias(name)
      config[:aliases][dasherize(name)] || name
    end

    def embed
      return if files.empty?
      case config[:format]
      when "html"
        html
      when "js"
        js
      when "css"
        css
      end
    end

    def read_files
      @files = {}

      # Get a list of svg files and modification times
      #
      find_files.each do |f|
        files[f] = File.mtime(f)
      end

      puts "Read #{files.size} files from #{config[:path]}" if config[:cli]

      process_files

      if files.empty? && config[:cli]
        puts "No svgs found at #{config[:path]}"
      end
    end

    # Add new svgs, update modified svgs, remove deleted svgs
    #
    def process_files
      files.each do |file, mtime|
        name = file_key(file)

        if svgs[name].nil? || svgs[name][:last_modified] != mtime
          svgs[name] = process_file(file, mtime, name)
        end
      end

      # Remove deleted svgs
      #
      (svgs.keys - files.keys.map {|file| file_key(file) }).each do |file|
        svgs.delete(file)
      end
    end

    def process_file(file, mtime, name)
      content = File.read(file).gsub(/<?.+\?>/,'').gsub(/<!.+?>/,'')
      {
        content: content,
        use: use_svg(name, content),
        last_modified: mtime
      }
    end

    def use_svg(file, content)
      name = classname(get_alias(file))
      %Q{<svg class="#{config[:base_class]} #{name}" #{dimensions(content)}><use xlink:href="##{name}"/></svg>}
    end

    def svg_icon(file, options={})
      embed = use_icon(file)
      embed = embed.sub(/class="(.+?)"/, 'class="\1 '+options[:class]+'"') if options[:class]
      embed = embed.sub(/><\/svg/, ">#{title(options)}#{desc(options)}</svg")
      embed
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
      if svgs[get_alias(name)].nil?
        raise "No svg named '#{name}' exists at #{config[:path]}"
      else
        svgs[name][:use]
      end
    end

    def classname(name)
      name = dasherize(name)
      if config[:namespace_before]
        "#{config[:namespace]}-#{name}"
      else
        "#{name}-#{config[:namespace]}"
      end
    end

    def dasherize(input)
      input.gsub(/[\W,_]/, '-').gsub(/-{2,}/, '-')
    end

    def find_files
      path = File.expand_path(File.join(config[:path], '*.svg'))
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

    def write
      return if @files.empty?
      case config[:format]
      when "html"
        write_html
        puts "Written to #{log_path config[:html_path]}" if config[:cli]
      when "js"
        write_js
        puts "Written to #{log_path config[:js_path]}" if config[:cli]
      when "css"
        write_css
        puts "Written to #{log_path config[:css_path]}" if config[:cli]
      end
    end

    def log_path(path)
      File.expand_path(path).sub(File.expand_path(Dir.pwd), '').sub(/^\//,'')
    end

    def write_svg(svg)
      path = File.join(config[:path], '.esvg-cache')
      write_file path, svg
      path
    end

    def write_js
      write_file config[:js_path], js
    end

    def write_css
      write_file config[:css_path], css
    end
    
    def write_html
      write_file config[:html_path], html
    end 

    def write_file(path, contents)
      FileUtils.mkdir_p(File.expand_path(File.dirname(path)))
      File.open(path, 'w') do |io|
        io.write(contents)
      end
    end

    def css
      styles = []
      
      classes = svgs.keys.map{|k| ".#{classname(k)}"}.join(', ')
      preamble = %Q{#{classes} { 
  font-size: #{config[:font_size]};
  clip: auto;
  background-size: auto;
  background-repeat: no-repeat;
  background-position: center center;
  display: inline-block;
  overflow: hidden;
  background-size: auto 1em;
  height: 1em;
  width: 1em;
  color: inherit;
  fill: currentColor;
  vertical-align: middle;
  line-height: 1em;
}}
      styles << preamble

      svgs.each do |name, data|
        if data[:css]
          styles << css
        else
          svg_css = data[:content].gsub(/</, '%3C') # escape <
                                  .gsub(/>/, '%3E') # escape >
                                  .gsub(/#/, '%23') # escape #
                                  .gsub(/\n/,'')    # remove newlines
          styles << data[:css] = ".#{classname(name)} { background-image: url('data:image/svg+xml;utf-8,#{svg_css}'); }"
        end
      end
      styles.join("\n")
    end

    def prep_svg(file, content)
      content = content.gsub(/<svg.+?>/, %Q{<svg class="#{classname(file)}" #{dimensions(content)}>})  # convert svg to symbols
             .gsub(/\n/, '')                 # Remove endlines
             .gsub(/\s{2,}/, ' ')            # Remove whitespace
             .gsub(/>\s+</, '><')            # Remove whitespace between tags
             .gsub(/style="([^"]*?)fill:(.+?);/m, 'fill="\2" style="\1')                   # Make fill a property instead of a style
             .gsub(/style="([^"]*?)fill-opacity:(.+?);/m, 'fill-opacity="\2" style="\1')   # Move fill-opacity a property instead of a style
             .gsub(/\s?style=".*?";?/,'')    # Strip style property
             .gsub(/\s?fill="(#0{3,6}|black|rgba?\(0,0,0\))"/,'')      # Strip black fill
    end

    def optimize(svg)
      if config[:optimize] && svgo?
        path = write_svg(svg)
        svg = `#{@svgo} '#{path}' -o -`
        FileUtils.rm(path)
      end

      svg
    end

    def html
      if @files.empty?
        ''
      else
        symbols = []
        svgs.each do |name, data|
          symbols << prep_svg(name, data[:content])
        end

        symbols = optimize(symbols.join).gsub(/class/,'id').gsub(/svg/,'symbol')

        %Q{<svg id="esvg-symbols" version="1.1" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" style="display:none">#{symbols}</svg>}
      end
    end

    def js
      %Q{var esvg = {
  embed: function(){
    if (!document.querySelector('#esvg-symbols')) {
      document.querySelector('body').insertAdjacentHTML('afterbegin', '#{html.gsub(/\n/,'').gsub("'"){"\\'"}}')
    }
  },
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
  load: function(){
    // If DOM is already ready, embed SVGs
    if (document.readyState == 'interactive') { this.embed() }

    // Handle Turbolinks (or other things that fire page change events)
    document.addEventListener("page:change", function(event) { this.embed() }.bind(this))

    // Handle standard DOM ready events
    document.addEventListener("DOMContentLoaded", function(event) { this.embed() }.bind(this))
  }
}

esvg.load()

// Work with module exports:
if(typeof(module) != 'undefined') { module.exports = esvg }
}
    end

    def svgo?
      @svgo ||= begin
        npm_path   = "#{config[:npm_path] || Dir.pwd}/node_modules"
        local_path = File.join(npm_path, "svgo/bin/svgo")

        if config[:npm_path] && !File.exist?(npm_path)
          abort "NPM Path not found: #{File.expand_path(config[:npm_path])}"
        end

        if File.exist?(local_path)
          local_path
        elsif `npm ls -g svgo`.match(/empty/).nil?
          "svgo"
        else
          false
        end
      end
    end

    def file_key(name)
      dasherize(File.basename(name, ".*"))
    end


    def symbolize_keys(hash)
      h = {}
      hash.each {|k,v| h[k.to_sym] = v }
      h
    end

  end
end
