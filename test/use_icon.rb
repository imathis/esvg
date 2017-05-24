require 'esvg'
require 'fileutils'

svgs = Esvg.new({config_file: '_alias.yml', source: 'svg_icons', temp: 'build/tmp'})

# Test standard svg icon usage
use = svgs.use_svg('comment-bubble')

# Test passing properties to style attribute
use_style = svgs.use_svg('comment-bubble', style: 'display: none', content: "<title>test</title>")
use_scale = svgs.use_svg('sub-folder/test', scale: true)
use_width = svgs.use_svg('sub-folder/test', width: '200px')

# Test alias for icon name
use_alias = svgs.use_svg('chat-bubble')

# Test fallback option
fallback = svgs.use_svg('boo', fallback: 'comment-bubble')

def log_path(path)
  File.expand_path(path).sub(File.expand_path(Dir.pwd), '').sub(/^\//,'')
end

def write_file(path, contents)
  path = File.expand_path(path)
  FileUtils.mkdir_p(File.dirname(path))
  File.open(path, 'w') do |io|
    io.write(contents)
    puts "Written to #{log_path path}"
  end
end

write_file('build/use/icon.html', use)
write_file('build/use/fallback.html', fallback)
write_file('build/use/alias.html', use_alias)
write_file('build/use/style.html', use_style)
write_file('build/use/scale.html', use_scale)
write_file('build/use/width.html', use_width)
