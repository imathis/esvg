var esvg = {
  embed: function(){
    if (!document.querySelector('#esvg-symbols')) {
      document.querySelector('body').insertAdjacentHTML('afterbegin', '<svg id="esvg-symbols" version="1.1" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" style="display:none"><symbol id="icon-comments" viewBox="0 0 512 512"><path d="M334.95 40.28H184.996c-90.954 0-164.947 73.996-164.947 164.947 0 80.714 58.267 148.074 134.956 162.213v62.716c0 12.13 7.306 23.064 18.513 27.707 3.71 1.537 7.606 2.283 11.47 2.283 7.804 0 15.474-3.046 21.213-8.785l81.187-81.185h47.56c90.95 0 164.946-74 164.946-164.947 0-90.952-73.996-164.947-164.945-164.947m0 29.99c74.534 0 134.955 60.422 134.955 134.958 0 74.53-60.42 134.953-134.955 134.955h-59.983l-89.97 89.973V340.18c-74.54 0-134.958-60.42-134.958-134.952 0-74.536 60.42-134.957 134.956-134.957h149.952"/></symbol></svg>')
    }
  },
  icon: function(name, classnames) {
    var svgName = this.iconName(name)
    var element = document.querySelector('#'+svgName)

    if (element) {
      return '<svg class="svg-icon '+svgName+' '+(classnames || '')+'" '+this.dimensions(element)+'><use xlink:href="#'+svgName+'"/></svg>'
    } else {
      console.error('File not found: "'+name+'.svg" at svg_icons/')
    }
  },
  iconName: function(name) {
    var before = true
    if (before) {
      return "icon-"+this.dasherize(name)
    } else {
      return name+"-icon"
    }
  },
  dimensions: function(el) {
    return 'viewBox="'+el.getAttribute('viewBox')+'" width="'+el.getAttribute('width')+'" height="'+el.getAttribute('height')+'"'
  },
  dasherize: function(input) {
    return input.replace(/[W,_]/g, '-').replace(/-{2,}/g, '-')
  },
  load: function(){
    // If DOM is already ready, embed SVGs
    if (document.readyState == 'interactive') { this.embed() }

    // Handle Turbolinks (or other things that fire page change events)
    document.addEventListener("page:change", function(event) { this.embed() })

    // Handle standard DOM ready events
    document.addEventListener("DOMContentLoaded", function(event) { this.embed() })
  }
}

esvg.load()

// Work with module exports:
if(typeof(module) != 'undefined') { module.exports = esvg }
