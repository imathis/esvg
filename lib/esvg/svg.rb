require 'yaml'

module Esvg
  class SVG
    attr_accessor :files, :svgs

    CONFIG = {
      path: Dir.pwd,
      base_class: 'svg-icon',
      namespace: 'icon',
      optimize: false,
      namespace_before: true,
      font_size: '1em',
      output_path: Dir.pwd,
      verbose: false,
      format: 'js'
    }

    CONFIG_RAILS = {
      path: "app/assets/esvg"
    }

    def initialize(options={})
      config(options)
      read_icons
      @cache = {}
    end

    def modified?
      @mtime != last_modified(find_files)
    end

    def embed
      return if @files.empty?
      case config[:format]
      when "html"
        html
      when "js"
        js
      when "css"
        css
      end
    end

    def svgo?
      @svgo ||= begin
         !(`npm ls -g svgo`.match(/empty/) && `npm ls svgo`.match(/emtpy/))
      end
    end

    def cache_name(input, options)
      "#{input}#{options.flatten.join('-')}"
    end

    def read_icons
      @files = {}
      @svgs  = {}

      found = find_files
      @mtime = last_modified(found)

      found.each do |f|
        @files[dasherize(File.basename(f, ".*"))] = read(f)
      end

      if @files.empty? && config[:verbose]
        puts "No icons found at #{config[:path]}"
      end
    end

    def last_modified(files)
      if files.size > 0
        File.mtime(files.sort_by{ |f| File.mtime(f) }.last)
      end
    end

    def read(file)
      if config[:optimize] && svgo?
        # Compress files outputting to $STDOUT
        `svgo #{file} -o -`
      else
        File.read(file)
      end
    end

    # Optiize all svg source files
    #
    def optimize
      if svgo?
        puts "Optimzing #{config[:path]}"
        system "svgo -f #{config[:path]}"
      else
        abort 'To optimize files, please install svgo; `npm install svgo -g`'
      end
    end

    def write
      return if @files.empty?
      case config[:format]
      when "html"
        write_html
      when "js"
        write_js
      when "css"
        write_css
      end
    end

    def write_file(path, contents)
      FileUtils.mkdir_p(File.expand_path(File.dirname(path)))
      File.open(path, 'w') do |io|
        io.write(contents)
      end
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

    def css
      @cache['css'] ||= begin
        styles = []
        
        classes = files.keys.map{|k| ".#{icon_name(k)}"}.join(', ')
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

        files.each do |name, contents|
          f = contents.gsub(/</, '%3C') # escape <
                      .gsub(/>/, '%3E') # escape >
                      .gsub(/#/, '%23') # escape #
                      .gsub(/\n/,'')    # remove newlines
          styles << ".#{icon_name(name)} { background-image: url('data:image/svg+xml;utf-8,#{f}'); }"
        end
        styles.join("\n")
      end
    end

    def html
      @cache['html'] ||= begin
        if @files.empty?
          ''
        else
          files.each do |name, contents|
            @svgs[name] = contents.gsub(/<svg.+?>/, %Q{<symbol id="#{icon_name(name)}" #{dimensions(contents)}>})  # convert svg to symbols
                           .gsub(/<\/svg/, '</symbol')     # convert svg to symbols
                           .gsub(/style=['"].+?['"]/, '')  # remove inline styles
                           .gsub(/\n/, '')                 # remove endlines
                           .gsub(/\s{2,}/, ' ')            # remove whitespace
                           .gsub(/>\s+</, '><')            # remove whitespace between tags
          end

          icons = @svgs

          %Q{<svg id="esvg-symbols" version="1.1" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" style="display:none">#{icons.values.join("\n")}</svg>}
        end
      end
    end

    def js
      @cache['js'] ||= begin
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
      console.error('File not found: "'+name+'.svg" at #{File.join(config[:path],'')}')
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
  }
}

// If DOM is already ready, embed SVGs
if (document.readyState == 'interactive') { esvg.embed() }

// Handle Turbolinks (or other things that fire page change events)
document.addEventListener("page:change", function(event) { esvg.embed() })

// Handle standard DOM ready events
document.addEventListener("DOMContentLoaded", function(event) { esvg.embed() })

// Work with module exports:
if(typeof(module) != 'undefined') { module.exports = esvg }
}
      end
    end

    def svg_icon(file, options={})
      file = dasherize(file.to_s)
      @cache[cache_name(file, options)] ||= begin 
        name = icon_name(file)
        %Q{<svg class="#{config[:base_class]} #{name} #{options[:class] || ""}" #{dimensions(@files[file])}><use xlink:href="##{name}"/>#{title(options)}#{desc(options)}</svg>}
      end
    end

    def title(options)
      if options[:title]
        "<title>#{options[:title]}</title>"
      end
    end

    def desc(options)
      if options[:desc]
        "<desc>#{options[:desc]}</desc>"
      end
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

        if config[:verbose]
          config[:path] = File.expand_path(config[:path])
          config[:output_path] = File.expand_path(config[:output_path])
        end

        config[:js_path]   ||= File.join(config[:output_path], 'esvg.js')
        config[:css_path]  ||= File.join(config[:output_path], 'esvg.css')
        config[:html_path] ||= File.join(config[:output_path], 'esvg.html')
        config.delete(:output_path)

        config
      end
    end

    def symbolize_keys(hash)
      h = {}
      hash.each {|k,v| h[k.to_sym] = v }
      h
    end

    def dimensions(input)
      dimensions = [] 
      %w(viewBox height width).map do |dimension|
          dimensions << input.scan(/<svg.+(#{dimension}=["'].+?["'])/).flatten.first
      end
      dimensions.compact.join(' ')
    end

    def icon_name(name)
      if @files[name].nil?
        raise "No icon named '#{name}' exists at #{config[:path]}"
      end
      classname(name)
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

  end
end
