module Jekyll
  class << self
    attr_accessor :esvg
    attr_accessor :esvg_embedded
  end
end

Jekyll::Hooks.register :site, :post_read do |site|
  site.exclude.push '.esvg-cache'
  Jekyll.esvg = Esvg.seed_cache(site.config["esvg"] || {})
end

Jekyll::Hooks.register :site, :post_write do |site|
  Jekyll.esvg.build unless Jekyll.esvg_embedded
end

module Jekyll
  module Tags
    class EmbedSvgs < Liquid::Tag
      def initialize(tag_name, markup, tokens)
        super
        @markup = markup.gsub(/["']/,'').split(/,\s*/)
      end

      def render(context)
        super
        if Jekyll.env == 'production'

          config   = context.registers[:site].config
          dest     = config["destination"]
          url      = Jekyll.esvg.config[:build].sub(dest, '')
          root_url = File.join config["baseurl"], url

          Esvg.build_paths(@markup).map { |path| %Q{<script src="#{File.join(root_url, path)}" async="true"></script>} }.join("\n")
        else
          Jekyll.esvg_embedded = true
          Esvg.embed()
        end
      end
    end

    class UseSvg < Liquid::Tag
      def initialize(tag_name, markup, tokens)
        super
        markup.sub!(/(\S+) /) do
          @name = $1.gsub(/[",']/, '')
          ''
        end

        @options = markup.strip.split(/,\s*/).join("\n")

        if @options.empty?
          @options = {}
        else
          @options = Jekyll::Utils.symbolize_hash_keys(YAML.load(@options)) unless @options.empty?
        end
      end

      def render(context)
        Esvg.use(@name, @options)
      end
    end
  end
end

Liquid::Template.register_tag('use_svg', Jekyll::Tags::UseSvg)
Liquid::Template.register_tag('esvg', Jekyll::Tags::EmbedSvgs)
