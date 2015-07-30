require 'yaml'

module Esvg
  class SVG
    attr_accessor :files

    CONFIG = {
      path: Dir.pwd,
      base_class: 'svg-icon',
      namespace: 'icon',
      optimize: false,
      namespace_before: true,
      font_size: '1em',
      output_path: Dir.pwd,
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

    def modified?
      mtime = File.mtime(find_files.last)
      @mtime != mtime
    end

    def svgo?
      @has_svgo ||= begin
        config[:optimize] && !(`npm ls -g svgo`.match(/empty/) && `npm ls svgo`.match(/emtpy/))
      end
    end

    def cache_name(input, options)
      input + options.flatten.join('-')
    end

    def optimize(file)
      if svgo?
        `svgo #{file} -o -`
      else
        File.read(file)
      end
    end

    def read_icons
      @files = {}
      @mtime = {}
      @svgs  = {}

      found = find_files
      @mtime = File.mtime(found.last)

      found.each do |f|
        @files[File.basename(f, ".*")] = optimize(f)
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
  clip: auto;
  font-size: #{config[:font_size]};
  background-size: auto 1em;
  background-repeat: no-repeat;
  background-position: center center;
  display: inline-block;
  overflow: hidden;
  height: 1em;
  width: 1em;
  color: transparent;
  vertical-align: middle;
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
  }
}

// If DOM is already ready, embed SVGs
if (document.readyState == 'interactive') { esvg.embed() }

// Handle Turbolinks (or other things that fire page change events)
document.addEventListener("page:change", function(event) { esvg.embed() })

// Handle standard DOM ready events
document.addEventListener("DOMContentLoaded", function(event) { esvg.embed() })
}
      end
    end

    def svg_icon(file, options={})
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

        config = if path = paths.select{ |p| File.exist?(p)}.first
          CONFIG.merge(symbolize_keys(YAML.load(File.read(path) || {})))
        else
          CONFIG
        end

        config.merge!(CONFIG_RAILS) if Esvg.rails?
        config.merge!(options)

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
        raise "No icon named #{name} exists at #{config[:path]}"
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
      input.gsub(/\W/, '-').gsub(/-{2,}/, '-')
    end

    def find_files
      path = File.join(config[:path], '*.svg')

      Dir[path].uniq.sort_by{ |f| File.mtime(f) }
    end

  end
end
