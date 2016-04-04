/*jslint browser: true, devel: true */
/*global  App */

window.App = window.App || {};
(function ($) {
	"use strict";
	
	App.Tickets = {
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

			case 'helpdesk/tickets/index':
			case 'helpdesk/tickets/show':
				this.current_module = 'Merge_tickets';
				break;
				
			case 'helpdesk/tickets/compose_email':
				this.current_module = 'Compose';
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