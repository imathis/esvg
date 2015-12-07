require 'esvg'
Esvg.icons({config_file: '_alias.yml', path: 'svg_icons'})
use = Esvg.svg_icon('chat-bubble')

def write_file(path, contents)
  FileUtils.mkdir_p(File.expand_path(File.dirname(path)))
  File.open(path, 'w') do |io|
    io.write(contents)
  end
end

write_file('build/use.html', use)
