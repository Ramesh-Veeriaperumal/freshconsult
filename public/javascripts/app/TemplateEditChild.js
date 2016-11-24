/*jslint browser: true, devel: true */
/*global  App */

// Edit child template js
window.App = window.App || {};
(function ($) {
	"use strict";
	
	App.Parentchildtemplates.EditChild = {
		onVisit: function (data) {
			App.Parentchildtemplates.initializeChildModel();
			App.Parentchildtemplates.intializeUnsavedModel();
			setTimeout(function(){
				App.Parentchildtemplates.getOldValues();
			},100);
			App.Parentchildtemplates.initializeEditInheritFeild(customMessages.inheritParentFields);
			App.Parentchildtemplates.initializeEditModel('child-delete-template');
		}
	}
}(window.jQuery));