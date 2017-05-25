require 'open3'

module Esvg
  class Symbol
    attr_reader :name, :id, :path, :content, :optimized, :size, :group, :mtime

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
      if @mtime != time
        @mtime   = time
        @content = pre_optimize File.read(@path)
        @size    = dimensions
        @optimized = nil
        @optimized_at = nil
      end
      @group = dir_key
      @name  = file_name
      @id    = file_id file_key

      self
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
        optimized: @optimized,
        optimized_at: @optimized_at
      }
    end

    def attr
      { id: @id, 'data-name': @name }.merge @size
    end

    def use(options={})
      if options[:color]
        options[:style] ||= ''
        options[:style] += "color:#{options[:color]};#{options[:style]}"
      end

      use_attr = {
        class: [@config[:class], @config[:prefix]+"-"+@name, options[:class]].compact.join(' '),
        viewBox: @size[:viewBox],
        style:  options[:style],
        fill:   options[:fill]
      }

      # If user doesn't pass a size or set scale: true
      if !(options[:width] || options[:height] || options[:scale])

        # default to svg dimensions
        use_attr[:width]  = @size[:width]
        use_attr[:height] = @size[:height]
      else

        # Add sizes (nil options will be stripped)
        use_attr[:width]  = options[:width]
        use_attr[:height] = options[:height]
      end

      %Q{<svg #{attributes(use_attr)}>#{use_tag}#{title(options)}#{desc(options)}#{options[:content]||''}</svg>}
    end

    def use_tag(options={})
      options["xlink:href"] = "##{@id}"
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

    def optimize
      # Only optimize again if the file has changed
      return @optimized if @optimized && @optimized_at > @mtime

      @optimized = @content
      sub_def_ids

      if @config[:optimize] && Esvg.node_module('svgo')
        response = Open3.capture3(%Q{#{Esvg.node_module('svgo')} --disable=removeUselessDefs -s '#{@optimized}' -o -})
        @optimized = response[0] if response[2].success?
      end

      post_optimize
      @optimized_at = Time.now.to_i

      @optimized
    end

    private

    def load_data
      if c = @config[:cache]
        @path         = c[:path]
        @id           = c[:id]
        @name         = c[:name]
        @group        = c[:group]
        @mtime        = c[:mtime]
        @size         = c[:size]
        @content      = c[:content]
        @optimized    = c[:optimized]
        @optimized_at = c[:optimized_at]
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
          width: coords[2].to_i - coords[0].to_i,
          height: coords[3].to_i - coords[1].to_i
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
        .gsub(/class="def-/,'id="def-') # Replace <def> classes with ids (classes are generated in sub_def_ids)
        .gsub(/\w+=""/,'')              # Remove empty attributes
    end

    def set_attributes
      attr.keys.each do |key|
        @optimized.sub!(/ #{key}=".+?"/,'')
      end

      @optimized.sub!(/<svg/, "<symbol #{attributes(attr)}")
    end

    # Scans <def> blocks for IDs
    # If urls(#id) are used, ensure these IDs are unique to this file
    # Only replace IDs if urls exist to avoid replacing defs
    # used in other svg files
    #
    def sub_def_ids
      @optimized.scan(/<defs>.+<\/defs>/m).flatten.each do |defs|
        defs.scan(/id="(.+?)"/).flatten.uniq.each_with_index do |id, index|

          # If there are urls which refer to
          # ids be sure to update both
          #
          if @optimized.match(/url\(##{id}\)/)
            new_id = "def-#{@id}-#{index}"

            @optimized.gsub! /id="#{id}"/, %Q{class="#{new_id}"}
            @optimized.gsub! /url\(##{id}\)/, "url(##{new_id})"

          # Otherwise just leave the IDs of the
          # defs and change them to classes to 
          # avoid SVGO ID mangling
          #
          else
            @optimized.gsub! /id="#{id}"/, %Q{class="#{id}"}
          end
        end
      end
    end
  end
end
