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
    name = icons.icon_name(name)
    %Q{<svg class="icon #{name} #{options[:class] || ""}"><use xlink:href="##{name}"/>#{title(options)}#{desc(options)}</svg>}.html_safe
  end

  def rails?
    defined?(Rails)
  end

  private

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
end
