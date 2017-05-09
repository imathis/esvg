module Esvg::Helpers
  def esvg_embed(*keys)
    esvg_icons.embed_script(keys).html_safe
  end

  def esvg_use(name, options={})
    esvg_icons.use(name, options).html_safe
  end

  def esvg_icons
    svgs = Esvg.svgs || Esvg.new()

    svgs.read_files if Rails.env.development?

    svgs
  end
end
