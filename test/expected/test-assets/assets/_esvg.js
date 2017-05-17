(function(){
  var names

  function attr( source, name ){
    if (typeof source == 'object')
      return name+'="'+source.getAttribute(name)+'" '
    else
      return name+'="'+source+'" ' }

  function dasherize( input ) {
    return input.replace(/[\W,_]/g, '-').replace(/-{2,}/g, '-')
  }

  function svgName( name ) {
    return "svg-"+dasherize( name )
  }

  function use( name, options ) {
    options = options || {}
    var id = dasherize( svgName( name ) )
    var symbol = svgs()[id]

    if ( symbol ) {
      var svg = document.createRange().createContextualFragment( '<svg><use xlink:href="#'+id+'"/></svg>' ).firstChild;
      svg.setAttribute( 'class', 'svg-symbol '+id+' '+( options.classname || '' ).trim() )
      svg.setAttribute( 'viewBox', symbol.getAttribute( 'viewBox' ) )

      if ( !( options.width || options.height || options.scale ) ) {

        svg.setAttribute('width',  symbol.getAttribute('width'))
        svg.setAttribute('height', symbol.getAttribute('height'))

      } else {

        if ( options.width )  svg.setAttribute( 'width',  options.width )
        if ( options.height ) svg.setAttribute( 'height', options.height )
      }

      return svg
    } else {
      console.error('Cannot find "'+name+'" svg symbol. Ensure that svg scripts are loaded')
    }
  }

  function svgs(){
    if ( !names ) {
      names = {}
      for( var symbol of document.querySelectorAll( 'svg[id^=esvg] symbol' ) ) {
        names[symbol.id] = symbol
      }
    }
    return names
  }

  var esvg = {
    svgs: svgs,
    use: use
  }

  // Handle Turbolinks page change events
  if ( window.Turbolinks ) {
    document.addEventListener( "turbolinks:load", function( event ) { names = null; esvg.svgs() })
  }

  if( typeof( module ) != 'undefined' ) { module.exports = esvg }
  else window.esvg = esvg

})()