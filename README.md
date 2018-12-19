# Esvg

Easly slip optimized, cached svgs into your workflow using standalone CLI or the simple Rails integration.

1. Converts a directory full of SVGs into a an optimized SVG using symbols for each file.
2. Build a Javascript file to inject SVGs into pages, so it's easily cacheable.
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

Add `Esvg.precompile_assets` to your `config/initializers/assets.rb` to add build with `rake assets:precompile`.

Add SVG files to your `app/assets/svgs/` directory.

for example:

```
app/assets/svgs
 - logo.svg
 - share.svg
 - thumbs-up.svg
```

### Inject SVG symbols

Add this to a page or layout where SVGs should be available

```
<%= embed_svgs %>
```

**During development:**

This will embed a `<script>` which will place svg symbols at the top of your site's `<body>` as soon as the DOM is ready, and after any Turbolinks page load events.

**In Production:**

The `embed_svgs` view helper will write a `javascript_include_tag` to include the script (rather than embeding it in the page).
When you run `rake assets:precompile` this script will be built to `public/assets/svgs-{fingerprint}.js` (and a gzipped version).

This allows browsers to cache the javascript files and reduce the weight of downloading svgs for each page.

### Placing an SVG

To place an SVG, use the `use_svg` vew helper. This helper will embed an SVG `use` tag which will reference the appropriate symbol. Here's how it works.

```
# Syntax: use_svg name, [options]

# Standard example
<%= use_svg 'logo' %>

# Output:
# <svg class="svg-symbol svg-logo"><use xlink:href="#svg-logo"/></svg>

# Add custom classnames
<%= use_svg 'share', class: 'disabled' %>

# Output: 
# <svg class="svg-symbol svg-share disabled"><use xlink:href="#svg-share"/></svg>

# Add custom styles
<%= use_svg 'logo', style: 'fill: #c0ffee' %>

# Use presets (setup in config yaml)
<%= use_svg 'chevron', preset: 'icon' %>

# Use size classes (setup in config yaml)
<%= use_svg 'chevron', size: 'small' %>

# Output: 
# <svg class="svg-symbol svg-logo" style="fill: #coffee;"><use xlink:href="#svg-logo"/></svg>

# Add title and desc tags for SVG accessibility.
<%= use_svg 'kitten', title: "Mr. Snuggles", desc: "A graphic of a cat snuggling a ball of yarn" %>

# Output: 
# <svg class="icon kitten-icon"><use xlink:href="#kitten-icon"/>
#   <title>Mr. Snuggles</title>
#   <desc>A graphic of a cat snuggling a ball of yarn</desc>
# </svg>

# Provide fallback icon if an icon is missing (great for when you are generating icon names from code)
<%= use_svg 'missing', fallback: 'default' %>

```

## Usage: stand-alone CLI

```
# Syntax:
$ esvg PATH [options]

# Examples:
$ esvg                      # Read icons from current directory, write js to ./svgs.js
$ esvg icons                # Read icons from 'icons' directory, write js to ./svgs.js
$ esvg --output build       # Read icons from current directory, write js to build/svgs.js
$ esvg -c --config foo.yml  # Read confguration from foo.yml (otherwise, defaults to esvg.yml, or config/esvg.yml)
```

## Configuration

If you're using esvg from the command line, configuration files are read from `./esvg.yml` or you can pass a path with the `--config` option to read the config file from elsewhere.

```
source: .                   # Where to find SVG icons (Rails defaults to app/assets/esvg)
build: .                    # Where to write build files
assets: .                   # Where to write asset files (builds for directories beginning in _)
tmp: .                      # Write temporary cache files (will write to #{dir}/.esvg-cache/

class: svg-symbol           # All svgs with `use_svg` will have this base classname
namespace: svg              # Namespace for symbol ids, e.g 'svg-logo'
namespace_before: true      # Add namespace before, e.g. 'svg-logo', false would be 'logo-svg'

alias:                      # Add aliases for icon names
  comment: chat             # use "chat" to reference comment.svg
  error: bad, broken        # Use "bad" or "broken" to reference error.svg

presets:                    # Add named presets for setting common options
  icon:                     # Passing option preset: 'icon' will set these defaults
    height: 1em
    class: icon

sizes:                      # Define size classes for easy assignment
  small:                    # size classes override presets
    height: 10px
  medium:
    height: 20px
```

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/imathis/esvg. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](contributor-covenant.org) code of conduct.

## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).

