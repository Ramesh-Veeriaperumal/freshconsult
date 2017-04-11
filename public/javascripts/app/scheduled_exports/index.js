/*jslint browser: true, devel: true */
/*global  App */
// Index ticket schedule js

window.App = window.App || {};
(function ($) {
	"use strict";
  var $body = $('body')
	App.Ticketschedule.IndexSchedule = {
		onVisit: function (data) {
      App.Ticketschedule.bindToggleEvents();
		},

		onLeave: function (data) {
			if (this.current_module !== '') {
				this.current_module = '';
				App.Ticketschedule.unbindEvents();
			}
		}
	}
}(window.jQuery));
