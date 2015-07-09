module Esvg::Helpers
  def embed_svgs(options={})
    Esvg.embed_svgs(options)
  end

  def svg_icon(name, options={})
    Esvg.svg_icon(name, options)
  end
end
