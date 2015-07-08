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
			case 'contacts/create_contact':
			case 'contacts/update_contact':
				this.current_module = 'Contact_form';
				break;

			case 'contacts/show':
			case 'contacts/update_description_and_tags':
				this.current_module = 'Contact_show';
				break;
			}
		},

		onLeave: function (data) {
			if (this.current_module !== '') {
				this[this.current_module].onLeave();
				this.current_module = '';
			}

			if(typeof window.merge_class != "undefined"){
				delete window.merge_class;
				jQuery('body').off('.merge_contacts');
			}
		}
	};
}(window.jQuery));