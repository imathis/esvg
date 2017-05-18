(function(){

  function embed() {
    if (!document.querySelector('#esvg-svg-others')) {
      document.querySelector('body').insertAdjacentHTML('afterbegin', '<svg id="esvg-svg-others" version="1.1" style="height:0;position:absolute"><symbol id="svg-others-test" viewBox="0 0 253 160" width="253" height="160"style="fill-rule:evenodd;clip-rule:evenodd;stroke-linejoin:round;stroke-miterlimit:1.41421;"><g><g><path d="M252.318,86.336l-126.159,72.836l-126.159,-72.837l0.001,-13.499l126.159,72.839l126.158,-72.838l0,13.499Z" fill="url(#def-svg-others-test-0)" /><path d="M252.318,72.837l-126.158,72.838l-126.159,-72.839l126.158,-72.836l126.159,72.837Z" fill="url(#def-svg-others-test-1)" /><path d="M252.318,72.837l-126.158,72.838l-126.159,-72.839l126.158,-72.836l126.159,72.837Zm-251.317,-0.001l125.159,72.261l125.158,-72.26l-125.158,-72.26l-125.159,72.259Z" fill="#4d7594" /><path d="M8.355,84.372c0,0.955 -0.67,1.342 -1.497,0.865c-0.827,-0.478 -1.497,-1.638 -1.497,-2.592c0,-0.955 0.67,-1.342 1.497,-0.865c0.827,0.477 1.497,1.638 1.497,2.592" fill="#19ca48" /><path d="M119.154,148.774l0,-0.799l-97.666,-56.378l0,0.81l97.666,56.367Z" fill="#3d6484" /><path d="M13.672,87.439c0,0.954 -0.67,1.341 -1.497,0.864c-0.826,-0.477 -1.496,-1.638 -1.496,-2.592c0,-0.955 0.67,-1.342 1.496,-0.864c0.827,0.477 1.497,1.637 1.497,2.592" fill="#19ca48" /><path d="M19.059,90.545c0,0.955 -0.67,1.341 -1.497,0.864c-0.826,-0.477 -1.496,-1.637 -1.496,-2.592c0,-0.954 0.67,-1.341 1.496,-0.864c0.827,0.477 1.497,1.638 1.497,2.592" fill="#19ca48" /></g></g><defs><linearGradient id="def-svg-others-test-0" x1="0" y1="0" x2="1" y2="0" gradientUnits="userSpaceOnUse" gradientTransform="matrix(126.158,-70.2484,70.2484,126.158,126.159,149.85)"><stop offset="0" style="stop-color:#253d54;stop-opacity:0.980392"/><stop offset="1" style="stop-color:#35516a;stop-opacity:0.980392"/></linearGradient><linearGradient id="def-svg-others-test-1" x1="0" y1="0" x2="1" y2="0" gradientUnits="userSpaceOnUse" gradientTransform="matrix(107.612,-72.8683,72.8683,107.612,68.5533,111.409)"><stop offset="0" style="stop-color:#335774;stop-opacity:0.94902"/><stop offset="1" style="stop-color:#243e57;stop-opacity:0.94902"/></linearGradient></defs></symbol></svg>')
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