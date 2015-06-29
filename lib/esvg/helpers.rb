module Esvg::Helpers
  def svg_html
    Esvg::icons.html
  end

  def svg_icon(name, options={})
    name = Esvg.icons.icon_name(name)
    %Q{<svg class="icon #{name} #{options[:class] || ""}"><use xlink:href="##{name}"/></svg>}.html_safe
  end
end
