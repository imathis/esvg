require 'esvg'
require 'fileutils'

Esvg.icons({config_file: '_alias.yml', path: 'svg_icons'})
use = Esvg.svg_icon('chat-bubble')

def write_file(path, contents)
  path = File.expand_path(path)
  FileUtils.mkdir_p(File.dirname(path))
  File.open(path, 'w') do |io|
    io.write(contents)
    puts "written to #{path}"
  end
end

write_file('build/use.html', use)
