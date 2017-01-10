/*jslint browser: true, devel: true */
/*global  App */
// New child template js
window.App = window.App || {};
(function ($) {
	"use strict";
	
	App.Parentchildtemplates.NewChild = {
		onVisit: function (data) {
			App.Parentchildtemplates.initializeChildModel();
			App.Parentchildtemplates.intializeUnsavedModel();
			App.Parentchildtemplates.getOldValues();
			jQuery('#helpdesk_ticket_template_name').addClass('new_child_name');
			this.bindEvents();
		},
		bindEvents: function(data){
			$(window).on('beforeunload' , function () {
				if(customMessages && customMessages.existing){
					App.Parentchildtemplates.sessionStorageProcess('remove',customMessages.existing,'');
				}
			});	
		}
	}
}(window.jQuery));