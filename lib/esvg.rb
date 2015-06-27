require "svg_optimizer"
require "fileutils"

require "esvg/version"
if defined?(Rails)
  require "esvg/railtie" 
  require "esvg/helpers" 
end

module Esvg
  class SVG

    attr_accessor :files

    CONFIG = {
      path: Dir.pwd,
      namespace: 'icon',
      namespace_after: true,
      font_size: '1em',
      stylesheet_embed: false,
      output_path: Dir.pwd
    }

    CONFIG_RAILS = {
      path: "app/assets/images/svg_icons",
      css_path: "app/assets/stylesheets/_svg_icons.scss",
      html_path: "app/views/shared/_svg_icons.html"
    }

    def initialize(options={})
      config(options)

      @files = {}

      find_files.each do |f|
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
        styles << ".#{property_name(name)} { background-image: url('data:image/svg+xml;utf-8,#{f}'); @extend %svg-icon; }"
      end
      styles.join("\n")
    end

    def html
      if @files.empty?
        ''
      else
        svg = []
        svg << %Q{<svg class="icon-symbols" version="1.1" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" style="display:none">}
        files.each do |name, contents|
          svg << contents.gsub(/<svg.+?>/, %Q{<symbol id="#{property_name(name)}" #{dimensions(contents)}>})  # convert svg to symbols
                         .gsub(/<\/svg/, '</symbol')     # convert svg to symbols
                         .gsub(/style=['"].+?['"]/, '')  # remove inline styles
                         .gsub(/\n/, '')                 # remove endlines
                         .gsub(/\s{2,}/, ' ')            # remove whitespace
                         .gsub(/>\s+</, '><')            # remove whitespace between tags
        end
        svg << %Q{</svg>}
        svg.join("\n")
      end
    end

    def config(options={})
      @config ||= begin
        paths = [options[:config_file], 'config/esvg.yml', 'esvg.yml'].compact

        config = if path = paths.select{ |p| File.exist?(p)}.first
          CONFIG.merge(symbolize_keys(YAML.load(File.read(path) || {}))).merge(options)
        else
          CONFIG.merge(options)
        end

        config.merge!(CONFIG_RAILS) if rails_mode
        config.merge(options)

        config[:css_path]  ||= File.join(config[:output_path], 'esvg.scss')
        config[:html_path] ||= File.join(config[:output_path], 'esvg.html')
        config.delete(:output_path)

        config
      end
    end

    def rails_mode
      defined?(Rails)
    end

    def symbolize_keys(hash)
      h = {}
      hash.each {|k,v| h[k.to_sym] = v }
      h
    end

    def dimensions(input)
      dimensions = [] 
      %w(viewBox).map do |dimension|
          dimensions << input.scan(/<svg.+(#{dimension}=["'].+?["'])/).flatten.first
      end
      dimensions.compact.join(' ')
    end

    def property_name(file)
      name = dasherize(file)
      if config[:namespace_after]
        "#{name}-#{config[:namespace]}"
      else
        "#{config[:namespace]}-#{name}"
      end
    end

    def dasherize(input)
      input.gsub(/\W/, '-').gsub(/-+/, '-')
    end

    def find_files
      path = File.join(config[:path], '*.svg')

      Dir[path].uniq
    end

  end
end
