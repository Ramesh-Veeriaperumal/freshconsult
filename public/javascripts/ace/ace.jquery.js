// !!!IMPORTANT This jquery plugin requires the livequery plugin (Include is not included in the page) 

!function( $ ){

  "use strict"

	$.fn.aceeditor.defaults = {
	    mode: "liquid",
	    theme: "textmate"
	}

	$.fn.aceeditor = function ( selector ) {
		return this.each(function () {
		  $(this).delegate(selector || d, 'click', function (e) {
		    var li = $(this).parent('li')
		      , isActive = li.hasClass('open')

		    clearMenus()
		    !isActive && li.toggleClass('open')
		    return false
		  })
		})
	}

}( window.jQuery );
