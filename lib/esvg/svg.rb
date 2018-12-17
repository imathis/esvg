require 'zlib'
require 'digest'

module Esvg
  class Svg
    include Esvg::Utils

    attr_reader :asset, :vesion, :name

    def initialize(name, symbols, config={})
      @name = name
      @config = config
      @symbols = symbols
      @symbol_defs = []
      @asset = File.basename(name).start_with?('_')
      @version = @config[:version] || Digest::MD5.hexdigest(symbols.map(&:mtime).join)
    end

    def embed
      %Q{if (!document.querySelector('#esvg-#{id}')) {
      document.querySelector('body').insertAdjacentHTML('afterbegin', '#{svg}')
    }}
    end

    def named?(names=[])
      [names].flatten.map { 
        |n| dasherize(n) 
      }.include? dasherize(@name)
    end

    def id
      if @name == '.'
        'symbols'
      else
        dasherize "#{@config[:prefix]}-#{name_key}"
      end
    end

    def path
      @path ||= begin
        name = name_key

        if name.start_with?('_') # Is it an asset?
          File.join @config[:assets], "#{name}.js"
        else # or a build file?

          # User doesn't want a fingerprinted build file and hasn't set a version
          if !@config[:fingerprint] && !@config[:version]
            File.join @config[:build], "#{name}.js"
          else
            File.join @config[:build], "#{name}-#{@version}.js"
          end
        end
      end
    end

    private

    def name_key
      if @name == '_'  # Root level asset file
        "_#{@config[:filename]}".sub(/_+/, '_')
      elsif @name == '.'      # Root level build file
        @config[:filename]
      else
        @name
      end
    end

    def svg
      if @svg && @symbols.select(&:changed?).empty?
        @svg
      else
        attr = {
          "data-symbol-class" => @config[:class],
          "data-prefix" => @config[:prefix],
          "version" => "1.1",
          "style" => "height:0;position:absolute"
        }

        defs = @symbols.map(&:defs).compact.join
        defs = "<defs>#{defs}</defs>" unless defs.empty?

        symbols = @symbols.map(&:symbol).join.gsub("\n",'')

        @svg = %Q{<svg id="esvg-#{id}" #{attributes(attr)} data-turbolinks-permanent>#{defs}#{symbols}</svg>}
      end
    end

  end
end
