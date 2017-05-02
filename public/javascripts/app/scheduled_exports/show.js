/*jslint browser: true, devel: true */
/*global  App */
// show ticket schedule js

window.App = window.App || {};
(function ($) {
	"use strict";

	App.Ticketschedule.ShowSchedule = {
		onVisit: function (data) {
			App.Ticketschedule.initEmail();
			App.Ticketschedule.bindEvents();
			App.Ticketschedule.constructScheduleMessage();
			App.Ticketschedule.copyClipboard();
			App.Ticketschedule.scheduleValueChange();
		},

		onLeave: function (data) {
			if (this.current_module !== '') {
				this.current_module = '';
				App.Ticketschedule.unbindEvents();
			}
		}
	}
}(window.jQuery));
