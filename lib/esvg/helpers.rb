module Esvg::Helpers
  def embed_svgs
    Esvg.embed_svgs
  end

  def svg_icon(name, options={})
    Esvg.svg_icon(name, options)
  end
end
