module Esvg
  module Utils
    def dasherize(input)
      input.gsub(/[\W,_]/, '-').sub(/^-/,'').gsub(/-{2,}/, '-')
    end

    def sub_path(root, path)
      path.sub(File.join(root,''),'')
    end

    def symbolize_keys(hash)
      h = {}
      hash.each {|k,v| h[k.to_sym] = v }
      h
    end

    def attributes(hash)
      att = []
      hash.each do |key, value|
        att << %Q{#{key}="#{value}"} unless value.nil?
      end
      att.join(' ')
    end

    def sort(hash)
      sorted = {}
      hash.sort.each do |h|
        sorted[h.first] = h.last
      end
      sorted
    end

    # Determine if an NPM module is installed by checking paths with `npm bin`
    # Returns path to binary if installed
    def node_module(cmd)
      require 'open3'

      @modules ||= {}

      return @modules[cmd] unless @modules[cmd].nil?

      @modules[cmd] = begin
        local = "$(npm bin)/#{cmd}"
        global = "$(npm -g bin)/#{cmd}"

        if Open3.capture3(local)[2].success?
          local
        elsif Open3.capture3(global)[2].success?
          global
        else
          false
        end
      end
    end

    def compress(file)
      mtime = File.mtime(file)
      gz_file = "#{file}.gz"

      return if (File.exist?(gz_file) && File.mtime(gz_file) >= mtime)

      File.open(gz_file, "wb") do |dest|
        gz = ::Zlib::GzipWriter.new(dest, Zlib::BEST_COMPRESSION)
        gz.mtime = mtime.to_i
        IO.copy_stream(open(file), gz)
        gz.close
      end

      File.utime(mtime, mtime, gz_file)

      gz_file
    end

  end
end
