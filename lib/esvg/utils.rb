module Esvg
  module Utils
    def dasherize(input)
      input.gsub(/[\W,_]/, '-').sub(/^-/,'').gsub(/-{2,}/, '-')
    end

    def sub_path(root, path)
      path.sub(File.join(root,''),'')
    end

    def attributes(hash)
      att = []
      hash.each do |key, value|
        att << %Q{#{key.to_s.gsub(/_/,'-')}="#{value}"} unless value.nil?
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
