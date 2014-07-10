/*
 * @author venom
 * Portal common page scripts
 */

jQuery.noConflict()
 
!function( $ ) {

	// Placeholder polyfill settings
	Modernizr.load({
	    test: Modernizr.input.placeholder,
	    nope: [
	            '/polyfills/placeholder/jquery.placeholder.js'
	          ],
	    complete : function () {
	    	if(!Modernizr.input.placeholder){
			    // Run this after everything in this group has downloaded
		      	// and executed, as well everything in all previous groups
		      	$('input[placeholder], textarea[placeholder]').placeholder();
		    }
	    }

	});

}(window.jQuery);