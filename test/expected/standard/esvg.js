var esvg = {
  embed: function(){
    if (!document.querySelector('#esvg-symbols')) {
      document.querySelector('body').insertAdjacentHTML('afterbegin', '<svg id="esvg-symbols" version="1.1" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" style="display:none"><?xml version="1.0" standalone="no"?><!DOCTYPE svg PUBLIC "-//W3C//DTD SVG 1.1//EN" "http://www.w3.org/Graphics/SVG/1.1/DTD/svg11.dtd"><symbol id="icon-comments" viewBox="0 0 512 512" height="100%" width="100%"><path id="Icons" d="M334.95,40.28l-149.954,0c-90.954,0 -164.947,73.996 -164.947,164.947c0,80.714 58.268,148.074 134.957,162.213l0,62.716c0,12.129 7.306,23.064 18.513,27.707c3.71,1.537 7.607,2.283 11.47,2.283c7.805,0 15.475,-3.046 21.214,-8.785l81.187,-81.186l47.561,0c90.949,0 164.945,-74 164.945,-164.947c0,-90.952 -73.996,-164.947 -164.945,-164.947M334.95,70.271c74.534,0 134.955,60.421 134.955,134.957c0,74.531 -60.421,134.953 -134.955,134.955l0,0.001l-59.983,0l-89.971,89.972l0,-89.972l0,-0.003c-74.538,0 -134.957,-60.422 -134.957,-134.953c0,-74.536 60.42,-134.957 134.957,-134.957l149.952,0" /></symbol></svg>')
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
    document.addEventListener("page:change", function(event) { this.embed() }.bind(this))

    // Handle standard DOM ready events
    document.addEventListener("DOMContentLoaded", function(event) { this.embed() }.bind(this))
  }
}

esvg.load()

// Work with module exports:
if(typeof(module) != 'undefined') { module.exports = esvg }
