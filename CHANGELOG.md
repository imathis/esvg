# Changelog

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
