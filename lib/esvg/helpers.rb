module Esvg::Helpers

  def embed_svgs(*keys)
    if Rails.env.production?
      esvg_files.build_paths(keys).each do |path|
        javascript_include_tag(path)
      end.join("\n")
    else
      esvg_files.embed_script(keys).html_safe
    end
  end

  def use_svg(name, options={})
    esvg_files.use(name, options).html_safe
  end

  def esvg_files
    svgs = Esvg.svgs || Esvg.new()

    svgs.read_files if Rails.env.development?

    svgs
  end
end
