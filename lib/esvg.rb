require "esvg/version"
require "svg_optimizer"

module Esvg
  extend self

  attr_accessor :config, :files

  def optimize(options)
    @config = {
      dir: Dir.pwd,
      namespace: 'icon',
      namespace_after: true,
      font_size: '1em',
    }.merge(options)

    config[:output] = if config[:filename]
      File.expand_path(config[:filename])
    else
      File.join(config[:dir],config[:output])
    end

    @files = {}

    find_files.each do |f|
      svg = File.read(f)
      @files[File.basename(f, ".*")] = SvgOptimizer.optimize(svg)
    end
    
    File.open(config[:output], 'w') do |io|
      io.write(output)
    end
  end 

  def output
    if config[:css]
      css
    elsif config[:html]
      html
    else
      abort 'no options'
    end
  end

  def css
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

  def property_name(file)
    name = dasherize(file)
    if config[:namespace_after]
      "#{name}-#{config[:namespace]}"
    else
      "#{config[:namespace]}-#{name}"
    end
  end

  def html
    svg = []
    svg << %Q{<svg xmlns="http://www.w3.org/2000/svg" width="312"><defs>}
    files.each do |name, contents|
      svg << contents.gsub(/<svg.+?>/, %Q{<g id="#{property_name(name)}" #{dimensions(contents)}>})
                     .gsub(/<\/svg/, '</g')
                     .gsub(/\n/, '')
    end
    svg << %Q{</defs></svg>}
    svg.join("\n")
  end

  def dimensions(input)
    dimensions = [] 
    %w(viewBox height width).map do |dimension|
        dimensions << input.scan(/<svg.+(#{dimension}=["'].+?["'])/).flatten.first
    end
    dimensions.compact.join(' ')
  end

  def dasherize(input)
    input.gsub(/\W/, '-').gsub(/-+/, '-')
  end

  def find_files
    path = File.join(config[:dir], '*.svg')

    Dir[path].uniq
  end

end
