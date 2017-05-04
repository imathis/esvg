require 'esvg'
require 'fileutils'

svgs = Esvg.new({config_file: '_alias.yml', path: 'svg_icons'})

p svgs.build_paths
