var esvg = {
  embed: function(){
    if (!document.querySelector('#esvg-symbols')) {
      document.querySelector('body').insertAdjacentHTML('afterbegin', '<svg id="esvg-symbols" version="1.1" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" style="display:none"><symbol id="icon-comment-bubble" viewBox="0 0 512 512" width="512" height="512"><path d="M334.95 40.28H184.996c-90.954 0-164.947 73.996-164.947 164.947 0 80.714 58.268 148.074 134.957 162.213v62.716a29.99 29.99 0 0 0 51.197 21.205l81.187-81.186h47.561c90.949 0 164.945-74 164.945-164.947 0-90.952-73.996-164.947-164.945-164.947m-.001 29.99c74.534 0 134.955 60.421 134.955 134.957 0 74.531-60.421 134.953-134.955 134.955v.001h-59.983l-89.971 89.972v-89.975c-74.538 0-134.957-60.422-134.957-134.953 0-74.536 60.42-134.957 134.957-134.957h149.952"/><path d="M334.95 70.271c74.534 0 134.955 60.421 134.955 134.957 0 74.531-60.421 134.953-134.955 134.955v.001h-59.983l-89.971 89.972v-89.975c-74.538 0-134.957-60.422-134.957-134.953 0-74.536 60.42-134.957 134.957-134.957H334.95z" fill-opacity=".435"/></symbol></svg>')
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
  },
  aliases: {},
  alias: function(name) {
    var aliased = this.aliases[name]
    if (typeof(aliased) != "undefined") {
      return aliased
    } else {
      return name
    }
  }
}

esvg.load()

// Work with module exports:
if(typeof(module) != 'undefined') { module.exports = esvg }
