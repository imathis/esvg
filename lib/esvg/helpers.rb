module Esvg::Helpers

  def esvg
    svgs = Esvg.svgs || Esvg.new()

    svgs.read_files if Rails.env.development?

    svgs
  end


  def embed_svgs(*keys)
    if Rails.env.production?
      esvg.build_paths(keys).map do |path|
        javascript_include_tag(path)
      end.join("\n").html_safe
    else
      esvg.embed_script(keys).html_safe
    end
  end

  def use_svg(name, options={}, &block)
    use_svg_with_files(esvg, name, options, &block)
  end

  private

  def use_svg_with_files(files, name, options, &block)

    if block_given?
      options[:content] = capture(&block)
    end

    files.use(name, options).html_safe
  end
end
