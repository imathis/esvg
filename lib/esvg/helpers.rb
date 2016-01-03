module Esvg::Helpers
  def embed_svgs(options={})
    Esvg.icons(options).embed.html_safe
  end

  def svg_icon(name, options={})
    name = dasherize(name)

    begin
      icon_svg = Esvg.icons.svg_icon(name, options).html_safe
    rescue Exception => e
      raise e if !Rails.env.production?
      icon_svg = ''
    end

    icon_svg
  end

  def dasherize(input)
    input.gsub(/[\W,_]/, '-').gsub(/-{2,}/, '-')
  end

end
