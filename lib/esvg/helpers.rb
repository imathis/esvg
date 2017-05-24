module Esvg::Helpers

  def embed_svgs(*keys)
    Esvg.embed(keys)
  end

  def use_svg(name, options={}, &block)
    options[:content] = capture(&block).html_safe if block_given?

    Esvg.use(name, options)
  end
end
