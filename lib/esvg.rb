require "fileutils"

require "esvg/version"
require "esvg/utils"
require "esvg/svgs"
require "esvg/svg"

if defined?(Rails)
  require "esvg/helpers" 
  require "esvg/railties" 
end

if defined?(Jekyll)
  require "esvg/jekyll_hooks" 
end

CONFIG = {
  filename: 'svgs',
  class: 'svg-symbol',
  prefix: 'svg',
  cache_file: '.symbols',
  core: true,
  optimize: false,
  gzip: false,
  scale: false,
  fingerprint: true,
  throttle_read: 4,
  flatten: [],
  alias: {}
}

CONFIG_RAILS = {
  source: "app/assets/svgs",
  assets: "app/assets/javascripts",
  build: "public/javascripts",
  temp: "tmp"
}

CONFIG_JEKYLL = {
  source: "_svgs",
  build: "javascripts",
  core: false
}

module Esvg

  extend self

  include Esvg::Utils
  def new(options={})
    @svgs ||=[]
    c = config(options)
    unless @svgs.find { |s| s.config[:source] == c[:source] }
      @svgs << Svgs.new(c)
    end
    @svgs.last
  end

  def svgs
    @svgs
  end

  def use(name, options={})
    if symbol = find_symbol(name, options)
      html_safe symbol.use options
    end
  end

  def use_tag(name, options={})
    if symbol = find_symbol(name, options)
      html_safe symbol.use_tag options
    end
  end

  def embed(names=nil)
    html_safe find_svgs(names).map{|s| s.embed_script(names) }.join
  end

  def build_paths(names=nil)
    find_svgs(names).map{|s| s.build_paths(names) }.flatten
  end

  def seed_cache(options)
    svgs = new(options)
    puts "Optimizing SVGs" if options[:print]
    svgs.symbols.map(&:optimize)
    svgs.write_cache
    svgs
  end

  def find_svgs(names=nil)
    @svgs.select {|s| s.buildable_svgs(names) }
  end

  def find_symbol(name, options={})
    if group = @svgs.find {|s| s.find_symbol(name, options[:fallback]) }
      group.find_symbol(name, options[:fallback])
    end
  end

  def rails?
    defined?(Rails) || File.exist?("./bin/rails")
  end

  def html_safe(input)
    input = input.html_safe if rails?
    input
  end

  def precompile_assets
    if defined?(Rails) && Rails.env.production? && defined?(Rake)
      ::Rake::Task['assets:precompile'].enhance do
        new(gzip: true, print: true).build
      end
    end
  end

  # Determine if an NPM module is installed by checking paths with `npm bin`
  # Returns path to binary if installed
  def node_module(cmd)
    @modules ||={}
    return @modules[cmd] if !@modules[cmd].nil?

    local = "$(npm bin)/#{cmd}"
    global = "$(npm -g bin)/#{cmd}"

    @modules[cmd] = if Open3.capture3(local)[2].success?
      local
    elsif Open3.capture3(global)[2].success?
      global
    else
      false
    end
  end

  def symbolize_keys(hash)
    h = {}
    hash.each {|k,v| h[k.to_sym] = v }
    h
  end

  def config(options={})
    paths = [options[:config_file], 'config/esvg.yml', 'esvg.yml'].compact

    config = CONFIG.dup

    if Esvg.rails? || options[:rails]
      config.merge!(CONFIG_RAILS)
    elsif defined?(Jekyll)
      config.merge!(CONFIG_JEKYLL)
    end

    if path = paths.select{ |p| File.exist?(p)}.first
      config.merge!(symbolize_keys(YAML.load(File.read(path) || {})))
    end

    config.merge!(options)

    if defined? Jekyll
      config[:build] = File.join(config[:destination], config[:build])
      config[:source] = File.join(config[:source_dir], config[:source])
    end

    config[:filename] = File.basename(config[:filename], '.*')

    config[:pwd]      = File.expand_path Dir.pwd
    config[:source]   = File.expand_path config[:source] || config[:pwd]
    config[:build]    = File.expand_path config[:build]  || config[:pwd]
    config[:assets]   = File.expand_path config[:assets] || config[:pwd]

    config[:temp]     = config[:pwd] if config[:temp].nil?
    config[:temp]     = File.expand_path File.join(config[:temp], '.esvg-cache')

    config[:aliases] = load_aliases(config[:alias])
    config[:flatten] = [config[:flatten]].flatten.map { |dir| File.join(dir, '/') }.join('|')

    config
  end
  
  # Load aliases from configuration.
  #  returns a hash of aliasees mapped to a name.
  #  Converts configuration YAML:
  #    alias:
  #      foo: bar
  #      baz: zip, zop
  #  To output:
  #    { :bar => "foo", :zip => "baz", :zop => "baz" }
  #
  def load_aliases(aliases)
    a = {}
    aliases.each do |name,alternates|
      alternates.split(',').each do |val|
        a[dasherize(val.strip).to_sym] = dasherize(name.to_s)
      end
    end
    a
  end

  def dasherize(input)
    input.gsub(/[\W,_]/, '-').sub(/^-/,'').gsub(/-{2,}/, '-')
  end

end
