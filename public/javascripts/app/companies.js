/*jslint browser: true, devel: true */
/*global  App */

window.App = window.App || {};
(function ($) {
	"use strict";
	
	App.Companies = {
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

			case 'companies/show':
			case 'companies/update_notes':
				this.current_module = 'Company_show';
				break;
			case 'companies/edit':
			case 'companies/new':
			case 'companies/create_company':
			case 'companies/update_company':
				this.current_module = 'Company_form';
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