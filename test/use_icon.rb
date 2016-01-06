require 'esvg'
require 'fileutils'

svgs = Esvg.new({config_file: '_alias.yml', path: 'svg_icons'})

# Test standard svg icon usage
use = svgs.svg_icon('comment-bubble')

# Test passing properties to style attribute
use_style = svgs.svg_icon('comment-bubble', style: 'display: none')

# Test alias for icon name
use_alias = svgs.svg_icon('chat-bubble')

# Test fallback option
fallback = svgs.svg_icon('boo', fallback: 'comment-bubble')

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
write_file('build/use/alias.html', use_alias)
write_file('build/use/style.html', use_style)
