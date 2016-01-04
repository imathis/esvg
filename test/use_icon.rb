require 'esvg'
require 'fileutils'

svgs = Esvg.new({config_file: '_alias.yml', path: 'svg_icons'})
use = svgs.svg_icon('chat_bubble')
fallback = svgs.svg_icon('boo', fallback: 'chat-bubble')
use_style = svgs.svg_icon('chat-bubble', style: 'display: none')

def write_file(path, contents)
  path = File.expand_path(path)
  FileUtils.mkdir_p(File.dirname(path))
  File.open(path, 'w') do |io|
    io.write(contents)
    puts "written to #{path}"
  end
end

write_file('build/use/icon.html', use)
write_file('build/use/fallback.html', fallback)
write_file('build/use/style.html', use_style)
