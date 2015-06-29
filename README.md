# Esvg

Easily embed optimized SVGs in HTML or CSS. Use as a standalone tool or with Rails.

[![Gem Version](http://img.shields.io/gem/v/esvg.svg)](https://rubygems.org/gems/esvg)
[![License](http://img.shields.io/:license-mit-blue.svg)](http://imathis.mit-license.org)

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'esvg'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install esvg

## Usage: Rails

Add SVG files to your `app/assets/svg_icons/` directory, then embed these SVGs in your application layout like this:

```
<head>
...
<%= embed_svgs %>
</head>
```

To reference an SVG, use the `svg_icon` helper.

```
# Syntax: svg_icon name, [options]

# Standard example
<%= svg_icon 'kitten' %>

# Output:
# <svg class="icon kitten-icon"><use xlink:href="#kitten-icon"/></svg>

# Add custom classnames
<%= svg_icon 'kitten', class: 'adorbs' %>

# Output: 
# <svg class="icon kitten-icon adorbs"><use xlink:href="#kitten-icon"/></svg>

# Add title and desc tags for SVG accessibility.
<%= svg_icon 'kitten', title: "Mr. Snuggles", desc: "A graphic of a cat snuggling a ball of yarn" %>

# Output: 
# <svg class="icon kitten-icon"><use xlink:href="#kitten-icon"/>
#   <title>Mr. Snuggles</title>
#   <desc>A graphic of a cat snuggling a ball of yarn</desc>
# </svg>
```

## Usage: stand-alone CLI

```
# Syntax:
$ esvg PATH [options]

# Examples:
$ esvg                          # Read icons from current directory, write HTML to ./esvg.html
$ esvg icons --output embedded  # Read icons from 'icons' directory, write HTML to embedded/esvg.html
$ esvg --stylesheet             # Embed icons in Stylesheet and write to ./esvg.scss
$ esvg --config foo.yml         # Read confguration from foo.yml
```

## Configuration: Rails

Esvg reads configuration from `config/esvg.yml` if used with Rails.

Options when used with Rails:

```
path: app/assets/svg_icons  # Where to find SVG icons
namespace: icon             # Add to the filename when creating symbol ids
namespace_after: true       # Add after the name, e.g. kitten-icon


stylesheet_embed: false     # Embed as a stylesheet
font_size: 1em              # Default size for SVGs (if embeded in stylesheets)
```

## Configuration: stand-alone CLI

If you're using esvg from the command line, configuration files are read from `./esvg.yml` or you can pass a path with the `--config` option to read the config file from elsewhere.

```
path: .                     # Where to find SVG icons
namespace: icon             # Add to the filename when creating symbol ids
namespace_after: true       # Add after the name, e.g. kitten-icon


stylesheet_embed: false     # Embed as a stylesheet
font_size: 1em              # Default size for SVGs (if embeded in stylesheets)

output_path: .              # Where to write output files
```

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/imathis/esvg. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](contributor-covenant.org) code of conduct.

## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).

