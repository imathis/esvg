require 'yaml'
require 'json'
require 'zlib'
require 'digest'
require 'esvg/symbol'

module Esvg
  class Svgs
    include Esvg::Utils

    attr_reader :symbols

    def initialize(options={})
      @config = options
      @symbols = []
      @svgs = []
      read_cache

      load_files
    end

    def production?
      @config[:env] == 'production'
    end

    def config
      # use cached configuration
      if !production? && config_expired? && config_changed?
        puts "Reloading ESVG config: #{print_path( @config[:config_file] )}" if @config[:print]
        @config = Esvg.update_config( @config )
      else
        @config
      end
    end

    def print_path( path )
      sub_path( @config[:root], path )
    end

    def config_expired?
      @config[:throttle_read] < (Time.now.to_i - @config[:read])
    end

    def config_changed?
      @config[:config_file] && @config[:read] < File.mtime( @config[:config_file] ).to_i
    end

    def loaded_recently?
      @last_load && (Time.now.to_i - @last_load) < @config[:throttle_read]
    end

    def load_files
      return if loaded_recently?

      files        = Dir[File.join(@config[:source], '**/*.svg')].uniq.sort
      size_before  = @symbols.size
      added        = []
      removed      = []

      # Remove all files which no longer exist
      @symbols.reject(&:exist?).each { |s| 
        removed.push @symbols.delete(s) 
      }

      files.each do |path|
        unless @symbols.find { |s| s.path == path }
          @symbols << Symbol.new(path, self)
          added.push @symbols.last
        end
      end

      if @config[:print]
        puts %Q{Read #{files.size} SVGs from #{print_path( @config[:source] )}}
        puts %Q{  Added: #{added.size} SVG#{'s' if added.size != 1} } if added.size > 0 
        puts %Q{  Removed: #{removed.size} SVG#{'s' if removed.size != 1} } if removed.size > 0 
      end

      @svgs.clear

      sort(@symbols.group_by(&:dir)).each do |name, symbols|
        @svgs << Svg.new(name, symbols, self)
      end

      @last_load = Time.now.to_i
      write_cache if cache_stale?

    end

    def build

      paths = []

      if @config[:core]
        path = File.join @config[:assets], "_esvg.js"
        write_file path, js_core
        paths << path
      end

      @svgs.each do |file|
        write_file file.path, js(file.embed)

        puts "Writing #{print_path( file.path )}" if @config[:print]
        paths << file.path

        if !file.asset && @config[:gzip] && gz = compress(file.path)
          puts "Writing #{print_path( gz )}" if @config[:print]
          paths << gz
        end
      end

      write_cache
      paths
    end

    def write_cache
      puts "Writing cache: #{ print_path( File.join( @config[:temp], @config[:cache_file]) )}" if @config[:print]
      write_tmp @config[:cache_file], @symbols.map(&:data).to_yaml
    end

    def read_cache
      (YAML.load(read_tmp(@config[:cache_file])) || []).each do |c|
        @config[:cache] = c
        @symbols << Symbol.new(c[:path], self)
      end
    end

    # Embed svg symbols
    def embed_script(names=nil)
      if production?
        embeds = buildable_svgs(names).map(&:embed)
      else
        embeds = find_svgs(names).map(&:embed)
      end

      write_cache if cache_stale?

      if !embeds.empty?
        "<script>#{js(embeds.join("\n"))}</script>"
      end

    end

    def cache_stale?
      path = File.join(@config[:temp], @config[:cache_file])

      # No cache file exists or cache file is older than a new symbol
      !File.exist?(path) || @symbols.size > 0 && File.mtime(path).to_i < @symbols.map(&:mtime).sort.last
    end

    def build_paths(names=nil)
      buildable_svgs(names).map{ |f| File.basename(f.path) }
    end

    def find_symbol(name, fallback=nil)
      # Ensure that file changes are picked up in development
      load_files unless production?

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
    return "#{@config[:prefix]}-"+dasherize( name )
  }

  function use( name, options ) {
    options = options || {}
    var id = dasherize( name )
    var symbol = svgs()[id]

    if ( symbol ) {
      var parent = symbol.parentElement
      var prefix = parent.dataset.prefix
      var base   = parent.dataset.symbolClass

      var svg = document.createRange().createContextualFragment( '<svg><use xlink:href="#' + prefix + '-' + id + '"/></svg>' ).firstChild;
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
      var symbols = Array.prototype.slice.call( document.querySelectorAll( 'svg[id^=esvg] symbol' ) )
      symbols.forEach( function( symbol ) {
        names[symbol.dataset.name] = symbol
      })
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
      @config[:aliases][dasherize(name).to_sym] || name
    end

    def write_tmp(name, content)
      path = File.join(@config[:temp], name)
      FileUtils.mkdir_p(File.dirname(path))
      write_file path, content
      path
    end

    def read_tmp(name)
      path = File.join(@config[:temp], name)
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
