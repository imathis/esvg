require 'open3'

module Esvg
  class Symbol
    attr_reader :name, :id, :path, :content, :optimized, :size, :group, :mtime, :defs

    include Esvg::Utils

    def initialize(path, config={})
      @config  = config
      @path    = path
      load_data
      read
    end

    def read
      return if !File.exist?(@path)

      time = last_modified

      # Ensure that cache optimization matches current optimization settings
      # If config has changed name, reset optimized build (name gets baked in)
      if @mtime != time || @svgo_optimized != svgo? || name != file_name
        @optimized = nil
        @optimized_at = nil
      end

      @group = dir_key
      @name  = file_name
      @id    = file_id file_key

      if @mtime != time
        @content = prep_defs pre_optimize File.read(@path)
        @mtime   = time
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
      if options[:color]
        options[:style] ||= ''
        options[:style] += "color:#{options[:color]};#{options[:style]}"
      end

      svg_attr = {
        class: [@config[:class], @config[:prefix]+"-"+@name, options[:class]].compact.join(' '),
        viewBox: @size[:viewBox],
        style:  options[:style],
        fill:   options[:fill],
        role: 'img'
      }

      # If user doesn't pass a size or set scale: true
      if options[:width].nil? && options[:height].nil? && !options[:scale]
        svg_attr[:width]  = width
        svg_attr[:height] = height
      else
        # Add sizes (nil options will be stripped)
        svg_attr[:width]  = options[:width]
        svg_attr[:height] = options[:height]
      end

      use_attr = {
        height: options[:height],
        width: options[:width],
        scale: options[:scale],
      }

      %Q{<svg #{attributes(svg_attr)}>#{use_tag(use_attr)}#{title(options)}#{desc(options)}#{options[:content]||''}</svg>}
    end

    def use_tag(options={})
      options["xlink:href"] = "##{@id}"

      # If user doesn't pass a size or set scale: true
      if options[:width].nil? && options[:height].nil? && options[:scale].nil?
        options[:width]  ||= width
        options[:height] ||= height
      end

      options.delete(:scale)

      %Q{<use #{attributes(options)}/>}
    end

    def title(options)
      if options[:title]
        "<title>#{options[:title]}</title>"
      else
        ''
      end
    end

    def desc(options)
      if options[:desc]
        "<desc>#{options[:desc]}</desc>"
      else
        ''
      end
    end

    def svgo?
      @config[:optimize] && !!Esvg.node_module('svgo')
    end

    def optimize
      # Only optimize again if the file has changed
      return @optimized if @optimized && @optimized_at > @mtime

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

    private

    def load_data
      if @config[:cache]
        @config.delete(:cache).each do |name, value|
          instance_variable_set("@#{name}", value)
        end
      end
    end

    def last_modified
      File.mtime(@path).to_i
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
        .gsub(/style="([^"]*?)fill:(.+?);/m, 'fill="\2" style="\1')                   # Make fill a property instead of a style
        .gsub(/style="([^"]*?)fill-opacity:(.+?);/m, 'fill-opacity="\2" style="\1')   # Move fill-opacity a property instead of a style
        .gsub(/\n/, '')                                      # Remove endlines
        .gsub(/\s{2,}/, ' ')                                 # Remove whitespace
        .gsub(/>\s+</, '><')                                 # Remove whitespace between tags
        .gsub(/\s?fill="(#0{3,6}|black|rgba?\(0,0,0\))"/,'') # Strip black fill
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
