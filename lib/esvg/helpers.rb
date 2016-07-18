module Esvg::Helpers
  def svg_icons(options={})
    svgs = Esvg.svgs

    if svgs.nil? || !options.empty?
      svgs = Esvg.new(options)
    end

    svgs.read_files if Rails.env.development?

    svgs
  end

  def svg_icon(name, options={})
    svg_icons.use(name, options).html_safe
  end
end
