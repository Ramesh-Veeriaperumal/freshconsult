/*jslint browser: true, devel: true */
/*global Topic:true, Fjax */
(function ($) {
	"use strict";

	Fjax.Callbacks = {
		init: function () {
			
		},

		codemirror: function () {
			$('[rel=codemirror]').livequery(function () {
          		$(this).codemirror($(this).data('codemirrorOptions'));
        	});
		},
			
		colorpicker: function () {
			// Colorpicker init below.
		},

		shortcut: function(){
			// Shortcut init below.
		}
		
	};
	
}(window.jQuery));