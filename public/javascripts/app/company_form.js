/*global  App */

window.App = window.App || {};
window.App.Companies.Company_form = window.App.Companies.Company_form || {};

(function ($) {
	"use strict";

	window.App.Companies.Company_form = {
		onFirstVisit: function (data) {
			this.onVisit(data);
		},
		onVisit: function(data) {
			 jQuery(".domain_tokens").select2({
		      tags: [],
		      tokenSeparators: [",", " "],
		      formatNoMatches: function () {
		        return "  ";
		      },
		      selectOnBlur: true
		    });
		},
		onLeave: function() {
			
		}
	};
}(window.jQuery));
