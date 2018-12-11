require 'open3'

module Esvg
  class Symbol
    attr_reader :name, :id, :path, :content, :optimized, :size, :group, :mtime, :defs

    include Esvg::Utils

    def initialize(path, config={})
      @config  = config
      @path    = path
      @last_checked = 0
      load_data
      read
    end

    def read
      return if !File.exist?(@path)

      # Ensure that cache optimization matches current optimization settings
      # If config has changed name, reset optimized build (name gets baked in)
      if changed? || @svgo_optimized != svgo? || name != file_name
        @optimized = nil
        @optimized_at = nil
      end

      @group = dir_key
      @name  = file_name
      @id    = file_id file_key

      if changed?
        @content = prep_defs pre_optimize File.read(@path)
        @mtime   = last_modified
        @size    = dimensions
      end

      self
    end

    def width
      @size[:width]
    end

    def height
      @size[:height]
    end

    # Scale width based on propotion to height
    def scale_width( h )
      s = split_unit( h )
      "#{( s[:size] / height * width ).round(2)}#{s[:unit]}"
    end

    # Scale height based on propotion to width
    def scale_height( w )
      s = split_unit( w )
      "#{( s[:size] / width * height ).round(2)}#{s[:unit]}"
    end

    # Separate size and unit for easier math.
    # Returns: { size: 10, unit: 'px' }
    def split_unit( size )
      m = size.to_s.match(/(\d+)\s*(\D*)/)
      { size: m[1].to_f, unit: m[2] }
    end

    def scale( a )
      # Width was set, determine scaled height
      if a[:width]
        a[:height] ||= scale_height( a[:width] )
      # Height was set, determine scaled width
      elsif a[:height]
        a[:width] ||= scale_width( a[:height] )
      # Nothing was set, default to dimensions
      else
        a[:width]  = width
        a[:height] = height
      end

      a
    end

    def data
      {
        path: @path,
        id: @id,
        name: @name,
        group: @group,
        mtime: @mtime,
        size: @size,
        content: @content,
        defs: @defs,
        optimized: @optimized,
        optimized_at: @optimized_at,
        svgo_optimized: svgo? && @svgo_optimized
      }
    end

    def attr
      { id: @id, 'data-name' => @name }.merge @size
    end

    def use(options={})
      options.delete(:fallback)
      content = options.delete(:content) || ''

      if desc   = options.delete(:desc)
        content = "<desc>#{desc}</desc>#{content}"
      end
      if title  = options.delete(:title)
        content = "<title>#{title}</title>#{content}"
      end

      use_attr = options.delete(:use) || {}

      svg_attr = {
        class: [@config[:class], @config[:prefix]+"-"+@name, options.delete(:class)].compact.join(' '),
        viewBox: @size[:viewBox],
        role: 'img'
      }.merge(options)

      if svg_attr[:scale]
        # User doesn't want dimensions to be set
        svg_attr.delete(:scale)
      else
        # Scale dimensions based on attributes
        svg_attr = scale( svg_attr )
      end

      %Q{<svg #{attributes(svg_attr)}>#{use_tag(use_attr)}#{content}</svg>}
    end

    def use_tag(options={})
      options["xlink:href"] = "##{@id}"

      if options[:scale] && @config[:scale]
        # User doesn't want dimensions to be set
        options.delete(:scale)
      else
        # Scale dimensions based on attributes
        options = scale( options )
      end

      options.delete(:scale)

      %Q{<use #{attributes(options)}></use>}
    end

    def svgo?
      @config[:optimize] && !!Esvg.node_module('svgo')
    end

    def optimize
      read if changed?

      # Only optimize again if the file has changed
      return @optimized if @optimized && @optimized_at && @optimized_at > @mtime

      @optimized = @content

      if svgo?
        response = Open3.capture3(%Q{#{Esvg.node_module('svgo')} --disable=removeUselessDefs -s '#{@optimized}' -o -})
        if !response[0].empty? && response[2].success?
          @optimized = response[0]
          @svgo_optimized = true
        end
      end

      post_optimize
      @optimized_at = Time.now.to_i

      @optimized
    end

    def changed?
      last_modified != mtime
    end

    private

    def load_data
      if @config[:cache]
        @config.delete(:cache).each do |name, value|
          instance_variable_set("@#{name}", value)
        end
      end
    end

    def last_modified
      if Time.now.to_i - @last_checked < @config[:throttle_read]
        @last_modified
      else
        @last_checked = Time.now.to_i
        @last_modified = File.mtime(@path).to_i
      end
    end

    def file_id(name)
      dasherize "#{@config[:prefix]}-#{name}"
    end

    def local_path
      @local_path ||= sub_path(@config[:source], @path)
    end

    def file_name
      dasherize flatten_path.sub('.svg','')
    end

    def file_key
      dasherize local_path.sub('.svg','')
    end

    def dir_key
      dir = File.dirname(flatten_path)

      # Flattened paths which should be treated as assets will use '_' as their dir key
      # - flatten: _foo - _foo/icon.svg will have a dirkey of _
      # - filename: _icons - treats all root or flattened files as assets
      if dir == '.' && ( local_path.start_with?('_') || @config[:filename].start_with?('_') )
        '_'
      else
        dir
      end
    end

    def flatten_path
      @flattened_path ||= local_path.sub(Regexp.new(@config[:flatten]), '')
    end

    def name_key(key)
      if key == '_'  # Root level asset file
        "_#{@config[:filename]}".sub(/_+/, '_')
      elsif key == '.'      # Root level build file
        @config[:filename]
      else
        "#{key}"
      end
    end

    def dimensions
      if viewbox = @content.scan(/<svg.+(viewBox=["'](.+?)["'])/).flatten.last
        coords  = viewbox.split(' ')

        {
          viewBox: viewbox,
          width: (coords[2].to_i - coords[0].to_i).abs,
          height: (coords[3].to_i - coords[1].to_i).abs
        }
      else
        {}
      end
    end

    def pre_optimize(svg)

      # Generate a regex of attributes to be removed
      att = Regexp.new %w(xmlns xmlns:xlink xml:space version).map { |m| "#{m}=\".+?\"" }.join('|')

      svg.strip
        .gsub(att, '')                                       # Remove unwanted attributes
        .sub(/.+?<svg/,'<svg')                               # Get rid of doctypes and comments
        .gsub(/<!--(.+?)-->/m, '')                           # Remove XML comments
        .gsub(/style="([^"]*?)fill:(.+?);/m, 'fill="\2" style="\1')                   # Make fill a property instead of a style
        .gsub(/style="([^"]*?)fill-opacity:(.+?);/m, 'fill-opacity="\2" style="\1')   # Move fill-opacity a property instead of a style
        .gsub(/\n/m, ' ')                                    # Remove endlines
        .gsub(/\s{2,}/, ' ')                                 # Remove whitespace
        .gsub(/>\s+</, '><')                                 # Remove whitespace between tags
        .gsub(/\s?fill="(#0{3,6}|black|none|rgba?\(0,0,0\))"/,'') # Strip black fill
    end

    def post_optimize
      @optimized = set_attributes
        .gsub(/<\/svg/,'</symbol')      # Replace svgs with symbols
        .gsub(/\w+=""/,'')              # Remove empty attributes
    end

    def set_attributes
      attr.keys.each do |key|
        @optimized.sub!(/ #{key}=".+?"/,'')
      end

      @optimized.sub(/<svg/, "<symbol #{attributes(attr)}")
    end

    # Scans <def> blocks for IDs
    # If urls(#id) are used, ensure these IDs are unique to this file
    # Only replace IDs if urls exist to avoid replacing defs
    # used in other svg files
    #
    def prep_defs(svg)

      # <defs> should be moved to the beginning of the SVG file for braod browser support. Ahem, Firefox ಠ_ಠ
      # When symbols are reassembled, @defs will be added back

      if @defs = svg.scan(/<defs>(.+)<\/defs>/m).flatten[0]
        svg.sub!("<defs>#{@defs}</defs>", '')
        @defs.gsub!(/(\n|\s{2,})/,'')

        @defs.scan(/id="(.+?)"/).flatten.uniq.each_with_index do |id, index|

          # If there are urls matching def ids
          if svg.match(/url\(##{id}\)/)

            new_id = "def-#{@id}-#{index}"                 # Generate a unique id
            @defs.gsub!(/id="#{id}"/, %Q{id="#{new_id}"})  # Replace the def ids
            svg.gsub!(/url\(##{id}\)/, "url(##{new_id})")  # Replace url references to these old def ids
          end
        end
      end

      svg
    end
  end
end
