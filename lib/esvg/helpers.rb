module Esvg::ActionView::Helpers
  def svg_html
    Esvg::SVG.new.html
  end

  def svg_icon(name, options={})
    name = Esvg::icon_name(name)
    %Q{<svg class="icon #{name} #{options[:class] || ""}"><use xlink:href="##{name}"/></svg>}
  end
end
