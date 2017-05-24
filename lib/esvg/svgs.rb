require 'yaml'
require 'json'
require 'zlib'
require 'digest'
require 'esvg/symbol'

module Esvg
  class Svgs
    include Esvg::Utils

    attr_reader :symbols

    CONFIG = {
      filename: 'svgs',
      class: 'svg-symbol',
      prefix: 'svg',
      core: true,
      optimize: false,
      gzip: false,
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

    def initialize(options={})
      config(options)
      @symbols = []
      @svgs = []
      @last_read = nil
      read_cache

      load_files
    end

    def config(options={})
      @config ||= begin
        paths = [options[:config_file], 'config/esvg.yml', 'esvg.yml'].compact

        config = CONFIG.dup

        if Esvg.rails? || options[:rails]
          config.merge!(CONFIG_RAILS)
        end

        if path = paths.select{ |p| File.exist?(p)}.first
          config.merge!(symbolize_keys(YAML.load(File.read(path) || {})))
        end

        config.merge!(options)

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
    end

    def load_files
      if !@last_read.nil? && (Time.now.to_i - @last_read) < config[:throttle_read]
        return
      end

      files = Dir[File.join(config[:source], '**/*.svg')].uniq.sort

      if files.empty? && config[:print]
        puts "No svgs found at #{config[:source]}"
        return
      end

      # Remove deleted files
      @symbols.reject(&:read).each { |s| @symbols.delete(s) }

      files.each do |path|
        unless @symbols.find { |s| s.path == path }
          @symbols << Symbol.new(path, config)
        end
      end

      @svgs.clear

      sort(@symbols.group_by(&:group)).each do |name, symbols|
        @svgs << Svg.new(name, symbols, config)
      end

      @last_read = Time.now.to_i

      puts "Read #{@symbols.size} files from #{config[:source]}" if config[:print]

    end

    def build

      paths = []

      if config[:core]
        path = File.join config[:assets], "_esvg.js"
        write_file path, js_core
        paths << path
      end

      @svgs.each do |file|
        write_file file.path, js(file.embed)

        puts "Writing #{file.path}" if config[:print]
        paths << file.path

        if !file.asset && config[:gzip] && gz = compress(file[:path])
          puts "Writing #{gz}" if config[:print]
          paths << gz
        end
      end

      write_cache
      paths
    end

    def write_cache
      write_tmp '.symbols', @symbols.map(&:data).to_yaml
    end

    def read_cache
      (YAML.load(read_tmp '.symbols') || []).each do |s|
        @symbols << Symbol.new(s[:path], config)
      end
    end

    # Embed only build scripts
    def embed_script(names=nil)
      embeds = buildable_svgs(names).map(&:embed)
      if !embeds.empty?
        "<script>#{js(embeds.join("\n"))}</script>"
      end
    end

    def build_paths(names=nil)
      buildable_svgs(names).map{ |f| File.basename(f.path) }
    end

    def find_symbol(name, fallback=nil)
      name = get_alias dasherize(name)

      if svg = @symbols.find { |s| s.name == name }
        svg
      elsif fallback
        find_symbol(fallback)
      end
    end

    def find_svgs(names=nil)
      return @svgs if names.nil? || names.empty?

      @svgs.select { |svg| svg.named?(names) }
    end

    def buildable_svgs(names=nil)
      find_svgs(names).reject(&:asset)
    end

    private

    def js(embed)
      %Q{(function(){

  function embed() {
    #{embed}
  }

  // If DOM is already ready, embed SVGs
  if (document.readyState == 'interactive') { embed() }

  // Handle Turbolinks page change events
  if ( window.Turbolinks ) {
    document.addEventListener("turbolinks:load", function(event) { embed() })
  }

  // Handle standard DOM ready events
  document.addEventListener("DOMContentLoaded", function(event) { embed() })
})()}
    end

    def js_core
      %Q{(function(){
  var names

  function attr( source, name ){
    if (typeof source == 'object')
      return name+'="'+source.getAttribute(name)+'" '
    else
      return name+'="'+source+'" ' }

  function dasherize( input ) {
    return input.replace(/[\\W,_]/g, '-').replace(/-{2,}/g, '-')
  }

  function svgName( name ) {
    return "#{config[:prefix]}-"+dasherize( name )
  }

  function use( name, options ) {
    options = options || {}
    var id = dasherize( name )
    var symbol = svgs()[id]

    if ( symbol ) {
      var parent = symbol.parentElement
      var prefix = parent.dataset.prefix
      var base   = parent.dataset.symbolClass

      var svg = document.createRange().createContextualFragment( '<svg><use xlink:href="#'+id+'"/></svg>' ).firstChild;
      svg.setAttribute( 'class', base + ' ' + prefix + '-' + id + ' ' + ( options.class || '' ).trim() )
      svg.setAttribute( 'viewBox', symbol.getAttribute( 'viewBox' ) )

      if ( !( options.width || options.height || options.scale ) ) {

        svg.setAttribute('width',  symbol.getAttribute('width'))
        svg.setAttribute('height', symbol.getAttribute('height'))

      } else {

        if ( options.width )  svg.setAttribute( 'width',  options.width )
        if ( options.height ) svg.setAttribute( 'height', options.height )
      }

      return svg
    } else {
      console.error('Cannot find "'+name+'" svg symbol. Ensure that svg scripts are loaded')
    }
  }

  function svgs(){
    if ( !names ) {
      names = {}
      for( var symbol of document.querySelectorAll( 'svg[id^=esvg] symbol' ) ) {
        names[symbol.dataset.name] = symbol
      }
    }
    return names
  }

  var esvg = {
    svgs: svgs,
    use: use
  }

  // Handle Turbolinks page change events
  if ( window.Turbolinks ) {
    document.addEventListener( "turbolinks:load", function( event ) { names = null; esvg.svgs() })
  }

  if( typeof( module ) != 'undefined' ) { module.exports = esvg }
  else window.esvg = esvg

})()}
    end

    def get_alias(name)
      config[:aliases][dasherize(name).to_sym] || name
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

    def write_tmp(name, content)
      path = File.join(config[:temp], name)
      FileUtils.mkdir_p(File.dirname(path))
      write_file path, content
      path
    end

    def read_tmp(name)
      path = File.join(config[:temp], name)
      if File.exist? path
        File.read path
      else
        ''
      end
    end

    def write_file(path, contents)
      FileUtils.mkdir_p(File.expand_path(File.dirname(path)))
      File.open(path, 'w') do |io|
        io.write(contents)
      end
    end
  end
end
