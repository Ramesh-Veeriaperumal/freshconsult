/*jslint browser: true, devel: true */
/*global  App */

// Edit template js
window.App = window.App || {};
(function ($) {
	"use strict";
	
	App.Parentchildtemplates.Edit = {
		onVisit: function (data) {
			App.Parentchildtemplates.getOldValues();
  		App.Parentchildtemplates.intializeUnsavedModel();
			if(jQuery('.ticket_template_form').data('parent-template')){
				jQuery('#helpdesk_ticket_template_name').addClass('edit_parent_name');
				App.Parentchildtemplates.initializeEditModel('edit-delete-template');
			}
		}
	}
}(window.jQuery));