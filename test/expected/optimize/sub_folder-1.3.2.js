(function(){

  function embed() {
    if (!document.querySelector('#esvg-svg-sub-folder')) {
      document.querySelector('body').insertAdjacentHTML('afterbegin', '<svg id="esvg-svg-sub-folder" version="1.1" style="height:0;position:absolute"><symbol id="svg-sub-folder-test" viewbox="0 0 512 512" width="512" height="512"><path d="M334.95 40.28H184.996c-90.954 0-164.947 73.996-164.947 164.947 0 80.714 58.268 148.074 134.957 162.213v62.716a29.99 29.99 0 0 0 51.197 21.205l81.187-81.186h47.561c90.949 0 164.945-74 164.945-164.947 0-90.952-73.996-164.947-164.945-164.947m-.001 29.99c74.534 0 134.955 60.421 134.955 134.957 0 74.531-60.421 134.953-134.955 134.955v.001h-59.983l-89.971 89.972v-89.975c-74.538 0-134.957-60.422-134.957-134.953 0-74.536 60.42-134.957 134.957-134.957h149.952"/></symbol>
</svg>')
    }
  }

  // If DOM is already ready, embed SVGs
  if (document.readyState == 'interactive') { embed() }

  // Handle Turbolinks page change events
  if ( window.Turbolinks ) {
    document.addEventListener("turbolinks:load", function(event) { embed() })
  }

  // Handle standard DOM ready events
  document.addEventListener("DOMContentLoaded", function(event) { embed() })
})()