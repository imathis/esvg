require "fileutils"

require "esvg/version"
require "esvg/svg"

if defined?(Rails)
  require "esvg/helpers" 
  require "esvg/railties" 
end

module Esvg
  extend self

  def new(options={})
    @svgs = SVG.new(options)
  end

  def svgs
    @svgs
  end

  def embed(key)
    new.embed(key)
  end

  def rails?
    defined?(Rails)
  end

end
