/*jslint browser: true, devel: true */
/*global  App */

window.App = window.App || {};
(function ($) {
	"use strict";
	
	App.Contacts = {
		current_module: '',

		onFirstVisit: function (data) {
			this.onVisit(data);
		},

		onVisit: function (data) {
			this.setSubModule();
			if (this.current_module !== '') {
				this[this.current_module].onVisit();
			}
		},

		setSubModule: function() {
			switch (App.namespace) {

			case 'contacts/new':
			case 'contacts/edit':
				this.current_module = 'Contact_form';
				break;

			case 'contacts/show':
				this.current_module = 'Contacts_merge';
				break;
			}
		},

		onLeave: function (data) {
			if (this.current_module !== '') {
				this[this.current_module].onLeave();
				this.current_module = '';
			}
		}
	};
}(window.jQuery));