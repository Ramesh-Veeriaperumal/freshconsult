/*jslint browser: true, devel: true */
/*global  App */

window.App = window.App || {};
(function ($) {
	"use strict";
	
	App.Contacts = {
		onFirstVisit: function () {
			console.log('This is the first time	into the Contacts Page');
		},
		onVisit: function () {
			console.log('Hi Again from the Contacts JS');
		},
		onLeave: function () {
			console.log('Leaving the Contacts Namespace');
		}
	};
}(window.jQuery));