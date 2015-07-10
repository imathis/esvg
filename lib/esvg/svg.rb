module Esvg
  class SVG
    attr_accessor :files

    CONFIG = {
      path: Dir.pwd,
      base_class: 'svg-icon',
      namespace: 'icon',
      namespace_after: true,
      font_size: '1em',
      stylesheet_embed: false,
      output_path: Dir.pwd,
      names: [],
      format: 'html'
    }

    CONFIG_RAILS = {
      path: "app/assets/svg_icons",
      css_path: "app/assets/stylesheets/_svg_icons.scss",
      html_path: "app/views/shared/_svg_icons.html"
    }

    def initialize(options={})
      config(options)
      read_icons
    end

    def embed
      case config[:format]
      when "html"
        html
      when "js"
        js
      when "css", 'scss', 'sass'
        stylesheet
      end
    end

    def modified?
      mtime = File.mtime(find_files.last)
      @mtime != mtime
    end

    def read_icons
      @files = {}
      @mtime = {}
      @svgs  = {}

      found = find_files
      @mtime = File.mtime(found.last)

      found.each do |f|
        svg = File.read(f)
        @files[File.basename(f, ".*")] = SvgOptimizer.optimize(svg)
      end
    end

    def write_stylesheet
      unless @files.empty?
        FileUtils.mkdir_p(File.expand_path(File.dirname(config[:css_path])))

        File.open(config[:css_path], 'w') do |io|
          io.write(stylesheet)
        end
      end
    end
    
    def write_html
      unless @files.empty?
        FileUtils.mkdir_p(File.expand_path(File.dirname(config[:html_path])))

        File.open(config[:html_path], 'w') do |io|
          io.write(html)
        end
      end
    end 

    def stylesheet
      styles = []
      preamble = %Q{%svg-icon { 
    clip: auto;
    font-size: #{config[:font_size]};
    background: {
      size: auto 1em;
      repeat: no-repeat;
      position: center center;
    }
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
        styles << ".#{icon_name(name)} { background-image: url('data:image/svg+xml;utf-8,#{f}'); @extend %svg-icon; }"
      end
      styles.join("\n")
    end

    def html
      names = Array(config[:names]) # In case a single string is passed

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

        if names.empty?
          icons = @svgs
        else
          icons = @svgs.select { |k,v| names.include?(k) }
        end

        %Q{<svg id="esvg-symbols" version="1.1" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" style="display:none">#{icons.values.join("\n")}</svg>}
      end
    end

    def js
      %Q{var esvg = {
  setup: function() {
  },
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

    def svg_icon(file, options={})
      name = icon_name(file)
      %Q{<svg class="#{config[:base_class]} #{name} #{options[:class] || ""}" #{dimensions(@files[file])}><use xlink:href="##{name}"/>#{title(options)}#{desc(options)}</svg>}.html_safe
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

        config[:css_path]  ||= File.join(config[:output_path], 'esvg.scss')
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
      if config[:namespace_after]
        "#{name}-#{config[:namespace]}"
      else
        "#{config[:namespace]}-#{name}"
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
