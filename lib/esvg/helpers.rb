module Esvg::Helpers

  def embed_svgs(*keys)
    if Rails.env.production?
      Esvg.build_paths(keys).map { |path| javascript_include_tag(path, async: true) }.join("\n").html_safe
    else
      Esvg.embed(keys)
    end
  end

  def use_svg(name, options={}, &block)
    options[:content] = capture(&block).html_safe if block_given?

    Esvg.use(name, options)
  end
end
