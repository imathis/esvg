require 'esvg'
require 'fileutils'

Esvg.new({config_file: '_alias.yml', source: 'svg_icons'})

# Test standard svg icon usage
embed_all        = Esvg.embed
embed_sub_folder = Esvg.embed('sub_folder')
all_paths        = Esvg.build_paths
sub_folder_paths = Esvg.build_paths('sub_folder')

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

write_file('build/embed/all.html', embed_all)
write_file('build/embed/sub_folder.html', embed_sub_folder)
write_file('build/embed/all_paths.html', all_paths)
write_file('build/embed/sub_folder_paths.html', sub_folder_paths)
