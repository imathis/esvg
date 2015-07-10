module Esvg::Helpers
  def embed_svgs(options={})
    Esvg.embed(options).html_safe
  end

  def svg_icon(name, options={})
    Esvg.svg_icon(name, options).html_safe
  end
end
