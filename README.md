# Esvg

Easily embed optimized SVGs in JS, HTML, or CSS. Use as a standalone tool or with Rails.

1. Converts a directory full of SVGs into a single optimized SVG using symbols.
2. Uses Javascript to inject SVGs into pages, so it's easily cacheable.
3. Offers Rails application helpers for placing icons in your views.

[![Gem Version](http://img.shields.io/gem/v/esvg.svg)](https://rubygems.org/gems/esvg)
[![Build Status](http://img.shields.io/travis/imathis/esvg.svg)](https://travis-ci.org/imathis/esvg)
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

First, add SVG files to your `app/assets/esvg/` directory.

### Inject SVG symbols

Then create an `esvg.js.erb` in your `app/assets/javascripts/` and add the following:

```
<%= Esvg.embed %>
```

Finally add the following to your `application.js`

```
//= require esvg
```

This script will inject your SVG symbols at the top of your site's `<body>` as soon as the DOM is ready, and after any Turbolinks `page:change` event.

### Place an icon

To place an SVG icon, use the `svg_icon` helper. This helper will embed an SVG `use` tag which will reference the appropriate symbol. Here's how it works.

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

# Add custom styles
<%= svg_icon 'kitten', style: 'color: #c0ffee' %>

# Output: 
# <svg class="icon kitten-icon" style="color: #coffee;"><use xlink:href="#kitten-icon"/></svg>

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
$ esvg                          # Read icons from current directory, write js to ./esvg.js
$ esvg icons                    # Read icons from 'icons' directory, write js to ./esvg.js
$ esvg --output embedded        # Read icons from current directory, write js to embedded/esvg.js
$ esvg -f --format              # Embed icons in Stylesheet and write to ./esvg.scss
$ esvg -c --config foo.yml      # Read confguration from foo.yml (otherwise, defaults to esvg.yml, or config/esvg.yml)
```

## Configuration

If you're using esvg from the command line, configuration files are read from `./esvg.yml` or you can pass a path with the `--config` option to read the config file from elsewhere.

```
path: .                     # Where to find SVG icons (Rails defaults to app/assets/esvg)
output_path: .              # Where to write output files (CLI only)
format: js                  # Format for output (js, html, css)

base_class: svg-icon        # Select all icons with this base classname
namespace: icon             # Namespace for symbol ids or CSS classnames
namespace_before: true      # Add namespace before, e.g. icon-kitten

alias:                      # Add aliases for icon names
  comment: chat             # use "chat" to reference comment.svg
  error: bad, broken        # Use "bad" or "broken" to reference error.svg

font_size: 1em              # Default size for SVGs (if embeded in stylesheets)
```

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/imathis/esvg. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](contributor-covenant.org) code of conduct.

## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).

