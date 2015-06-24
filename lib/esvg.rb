require "esvg/version"
require "svg_optimizer"

module Esvg
  extend self

  attr_accessor :config, :files

  def optimize(options)
    @config = {
      dir: Dir.pwd,
    }.merge(options)

    @files = {}

    find_files.each do |f|
      svg = File.read(f, ".*")
      @files[File.basename(f)] = SvgOptimizer.optimize(svg)
    end
    
    File.open(File.expand_path(config[:output]), 'w') do |io|
      io.write(output)
    end
  end 

  def output
    if config[:css]
      css
    elsif config[:html]
      abort 'not implemented yet'
    end
  end

  def css
    styles = []
    preamble = %Q{%esvg-icon { background-repeat: none; }}
    styles << preamble

    files.each do |name, contents|
      f = contents.gsub(/</, '%3C') # escape <
           .gsub(/>/, '%3E') # escape >
           .gsub(/#/, '%23') # escape #
      styles << ".#{dasherize(name)}-icon { background-image: url('data:image/svg+xml;utf-8,#{f}'); @extend %esvg-icon; }"
    end
    styles.join("\n")
  end

  def html
    # TODO: make this
  end

  def dasherize(input)
    input.gsub(/\W/, '-').gsub(/-+/, '-')
  end

  def find_files
    path = File.expand_path(File.join(config[:dir], '*.svg'))

    Dir[path].uniq
  end

  def config(options={})
  end
end
