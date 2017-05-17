(function(){

  function embed() {
    if (!document.querySelector('#esvg-symbols')) {
      document.querySelector('body').insertAdjacentHTML('afterbegin', '<svg id="esvg-symbols" version="1.1" style="height:0;position:absolute"><symbol id="svg-comment-bubble" viewbox="0 0 512 512" width="512" height="512"><path d="M334.95 70.271c74.534 0 134.955 60.421 134.955 134.957 0 74.531-60.421 134.953-134.955 134.955v.001h-59.983l-89.971 89.972v-89.975c-74.538 0-134.957-60.422-134.957-134.953 0-74.536 60.42-134.957 134.957-134.957H334.95z" fill-opacity=".435"/></symbol><symbol id="svg-root" viewbox="0 0 512 512" width="512" height="512"><path d="M334.95 70.271c74.534 0 134.955 60.421 134.955 134.957 0 74.531-60.421 134.953-134.955 134.955v.001h-59.983l-89.971 89.972v-89.975c-74.538 0-134.957-60.422-134.957-134.953 0-74.536 60.42-134.957 134.957-134.957H334.95z" fill-opacity=".435"/></symbol></svg>')
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