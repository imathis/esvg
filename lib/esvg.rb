require "fileutils"

require "esvg/version"
require "esvg/utils"
require "esvg/svgs"
require "esvg/svg"

if defined?(Rails)
  require "esvg/helpers" 
  require "esvg/railties" 
end

module Esvg
  extend self

  def new(options={})
    @svgs = Svgs.new(options)
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

  def build(options={})
    new(options).build
  end

  def precompile_assets
    if rails? && defined?(Rake)
      ::Rake::Task['assets:precompile'].enhance do
        build(gzip: true, print: true)
      end
    end
  end
end
