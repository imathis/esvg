# Changelog

### 4.4.3 (2018-12-09)
- IE 10 compatibility fix: Replaced self-closing `<use>` tag with close tag version.
- IE 10 compatibility fix: Using `forEach` instead of `for var of` because IE 10 is garbage. ¯\_(ツ)_/¯

### 4.4.2 (2018-12-07)
- Fix: Strips out fill=none, because Firefox doesn't let fill properties override SVGs with fill=none

### 4.4.0 (2018-08-06)
- New: Jekyll support. Just add esvg to the jekyll_plugins group in Gemfile and use {% esvg %} and {% use_svg %} as you'd expect.

### 4.3.9 (2017-09-05)
- Fix: Esvg javascript now properly appends prefixes when generating use tags.

### 2.9.2 (2016-08-31)
- Fix: Attributes width and height are now properly converted to strings.

### 2.9.1 (2016-07-18)
- New: `use` method is an alias for svg_icon
- Fix: Esvg.new caches instances to be used by Rails helper methods

### 2.9.0 (2016-07-18)
- New: `icon` method accepts fill, color, height, and width

### 2.8.10 (2016-07-01)
- Fix: Improved svgo detection; no longer requires svgo_path.

### 2.8.9 (2016-06-29)
- Fix: Now write path is returned after write.

### 2.8.8 (2016-02-23)
- Fix: Improved detection of Rails from CLI making it easier to use Rails defaults.

### 2.8.7 (2016-01-20)
- Fix: Fixed an accidental regex regression.

### 2.8.6 (2016-01-20)
- Fix: Some regexes weren't specific enough and were interfering with icon names.

### 2.8.5 (2016-01-08)
- Fix: Restored `svg_icon` helper to rails helpers.

### 2.8.4 (2016-01-05)
- Fix: Dasherize file names to avoid inconsistencies with underscores or dashes in filenames.
- Minor test improvements.

### 2.8.3 (2016-01-04)
- Fix: file read throttling
- Fix: Caching for Rails helper
- Improved tests covering dash vs. underscore usage

### 2.8.2 (2016-01-03)
- Fix: Rails helpers work better out of the box and hit the file system only when necessary.

### 2.8.1 (2015-12-16)
- Fix: Repeat icons no longer retain previous icon's options.

### 2.8.0 (2015-12-16)
- New: Added exist? method to ask if an icon exists.
- New: `fallback` option allows svgs to provide a fallback icon if one is not found.

### 2.7.0 (2015-12-08)
- New: Now option style can append to inlines styles

### 2.6.0 (2015-12-07)
- New: Alias mapping so several different names can be used to reference icons

### 2.5.0 (2015-11-03)
- Improved logging
- Added `--version` flag for CLI

### 2.4.3 (2015-10-27)
- Fix: Use proper svgo command when svgo is available.

### 2.4.2 (2015-10-26)
- Fix: Improved reliability and speed of optimization with svgo, by writing a temp file to the file system.

### 2.4.1 (2015-10-17)
- Fix: icon embedding (with ruby/rails) uses proper key for lookup.

### 2.4.0 (2015-10-17)
- New: Caching is now based on file modification times. It's much faster and more efficient.
- New: Optimization is much faster now too, as it happens after symbol concatenation, so it only runs once per build.
- Change: Configuration `svgo_path` is now `npm_path` and points to the path where the `node_modules` folder can be found.

### 2.3.1 (2015-10-15)
- Minor: Added `svgo_path` config option to specifiy a direct path to the svgo binary.

### 2.3.0 (2015-10-05)
- New: Now using viewport size to write svg dimensions. Some editors export SVG as 100% width and height, which is annoying if you want a set size.

### 2.2.5 (2015-10-02)
- Fix: Javascript binding issue.

### 2.2.4 (2015-10-02)
- Fix: Esvg load function happens inside of the module now.

### 2.2.3 (2015-10-02)
- Fix: Dasherize input when embedding icons from the ruby helper.

### 2.2.2 (2015-10-02)
- Fix: Improved lookup of last-modified file.

### 2.2.1 (2015-10-01)
- Fix: If no icons are found, it's cool, don't freak out.

### 2.2.0 (2015-09-30)
- New: New javascript helpers make it easier to inject SVG icons into javascript templates.
- New: Javascript works with module.exports if you're building Javascripts with a module requiring system.

### 2.1.1 (2015-09-29)
- Minor: `Esvg.icons.svgs` will now return the hash of svgs.

### 2.1.0 (2015-09-28)
- Fix: Ensure that symbols are converted to strings.
- Fix: Expand pahts for better error messages.

### 2.0.3 (2015-09-23)
- Fix: Fixed configuration merge order

### 2.0.2 (2015-07-10)
- Fix: Caching on just about everything.

### 2.0.1 (2015-07-10)
- Fix: Caching icons again is fixed.

### 2.0.0 (2015-07-10)
- New: Embed via JS for cacheable icon symbols
- New: Better integration with Rails
- Change: CLI flags and options have been updated.
- Change: CSS instead of Sass, for Stylesheet output.

### 1.1.2 (2015-06-30)

- Fix: Measuring modified time works better now.
- Fix: SVGs keep their dimensions when embedded.

### 1.1.1 (2015-06-29)

- Fix: Moved methods from Esvg module to SVG class. Oops.

### 1.1.0 (2015-06-29)

- New `embed_svgs` accepts an array, allowing a subset of icons to be embedded per page.

## 1.0.0 (2015-06-29)

- Initial release
