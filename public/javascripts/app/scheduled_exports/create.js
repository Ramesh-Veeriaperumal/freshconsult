/*jslint browser: true, devel: true */
/*global  App */
// create ticket schedule js

window.App = window.App || {};
(function ($) {
	"use strict";

	App.Ticketschedule.CreateSchedule = {
		onVisit: function (data) {
			App.Ticketschedule.initEmail();
			App.Ticketschedule.bindEvents();
			App.Ticketschedule.constructScheduleMessage();
			App.Ticketschedule.copyClipboard();
			App.Ticketschedule.scheduleValueChange();
			$('#scheduled_export_name').focus();
		},

		onLeave: function (data) {
			if (this.current_module !== '') {
				this.current_module = '';
				App.Ticketschedule.unbindEvents();
			}
		}
	}
}(window.jQuery));
