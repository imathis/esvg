require "svg_optimizer"
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
    @icons ||= SVG.new(options)

    if rails? && ::Rails.env != 'production' && @icons.modified?
      @icons.read_icons
    end

    @icons
  end

  def embed_svgs(names=[])
    icons.html(names).html_safe
  end

  def svg_icon(name, options={})
    icons.svg_icon(name, options)
  end

  def rails?
    defined?(Rails)
  end

end
