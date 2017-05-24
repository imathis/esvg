module Esvg::Helpers

  def esvg
    svgs = Esvg.svgs || Esvg.new()

    svgs.load_files if Rails.env.development?

    svgs
  end


  def embed_svgs(*keys)
    Esvg.embed(keys)
  end

  def use_svg(name, options={}, &block)
    options[:content] = capture(&block) if block_given?

    Esvg.use(name, options)
  end
end
