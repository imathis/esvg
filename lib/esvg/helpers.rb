module Esvg::Helpers
  def embed_svgs(names=[])
    Esvg.embed_svgs(names)
  end

  def svg_icon(name, options={})
    Esvg.svg_icon(name, options)
  end
end
