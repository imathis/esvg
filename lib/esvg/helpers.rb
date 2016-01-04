module Esvg::Helpers
  def svg_icons(options={})
    @@svg_icons ||= Esvg.new(options)
    @@svg_icons.read_files if Rails.env.development?
    @@svg_icons
  end
end
