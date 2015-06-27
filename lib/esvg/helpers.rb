module Esvg::ActionView::Helpers
  def svg_html
    Esvg::SVG.new.html
  end
end
