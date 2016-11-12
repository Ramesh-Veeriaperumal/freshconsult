/*jslint browser: true, devel: true */
/*global  App */

// index template js
window.App = window.App || {};
(function ($) {
	"use strict";
	
	App.Parentchildtemplates.Index = {
		onVisit: function (data) {
			this.initializeIndexModel('index-delete-template-modal');
		},
		initializeIndexModel: function(modalName){ // intialize index page modal popup
			$('body').append($('#'+modalName));
			$('#'+modalName).modal('hide');
		}
	}
}(window.jQuery));