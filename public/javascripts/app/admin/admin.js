/*jslint browser: true */
/*global  App */

window.App = window.App || {};
(function ($) {
	"use strict";

	App.Admin = {
		current_module: '',

		onFirstVisit: function (data) {
			this.onVisit(data);
		},
		onVisit: function (data) {
			this.setSubModule();
			this.bindHandlers();
			if (this.current_module !== '') {
				this[this.current_module].onVisit();
			}
		},

		setSubModule: function () {
			switch (App.namespace) {

			case 'admin/portal/index':
				this.current_module = 'Portal';
				break;
			}
		},

		bindHandlers: function () {

		},

		onLeave: function (data) {
			if (this.current_module !== '') {
				this[this.current_module].onLeave();
				this.current_module = '';
			}
		}
	};
}(window.jQuery));
