/*jslint browser: true, devel: true */
/*global  App */

// Clone template js
window.App = window.App || {};
(function ($) {
	"use strict";
	
	App.Parentchildtemplates.Clone = {
		onVisit: function (data) {
			if(jQuery('.ticket_template_form').data('parent-template')){
				jQuery('#helpdesk_ticket_template_name').addClass('edit_parent_name');
    		App.Parentchildtemplates.initializeEditModel();
    		App.Parentchildtemplates.intializeUnsavedModel();
   			App.Parentchildtemplates.getOldValues();
			}
		}
	}
}(window.jQuery));