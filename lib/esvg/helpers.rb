module Esvg::Helpers
  def embed_svgs(*keys)
    if Rails.env.production?
      esvg_icons.embed_script(keys).html_safe
    else
      esvg_icons.build_paths(keys).each do |path|
        javascript_include_tag(path)
      end.join("\n")
    end
  end

  def use_svgs(name, options={})
    esvg_icons.use(name, options).html_safe
  end

  def esvg_files
    svgs = Esvg.svgs || Esvg.new()

    svgs.read_files if Rails.env.development?

    svgs
  end
end
