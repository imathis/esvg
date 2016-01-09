module Esvg::Helpers
  def svg_icons(options={})
    @@svg_icons ||= Esvg.new(options)
    @@svg_icons.read_files if Rails.env.development?
    @@svg_icons
  end

  def svg_icon(name, options={})
    svg_icons.svg_icon(name, options).html_safe
  end
end
