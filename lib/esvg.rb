require "fileutils"

require "esvg/version"
require "esvg/svg"

if defined?(Rails)
  require "esvg/helpers" 
  require "esvg/railties" 
end

module Esvg
  extend self

  def icons(options={})
    if @icons.nil?
      @icons = SVG.new(options)
    elsif !rails? || (rails? && ::Rails.env.downcase != 'production')
      @icons.read_files
    end

    @icons
  end

  def embed(options={})
    icons(options).embed
  end

  def svg_icon(name, options={})
    @icons.svg_icon(name, options)
  end

  def exist?(name)
    @icons.exist?(name)
  end

  def rails?
    defined?(Rails)
  end

end
