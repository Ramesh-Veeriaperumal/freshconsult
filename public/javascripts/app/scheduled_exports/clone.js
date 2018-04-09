/*jslint browser: true, devel: true */
/*global  App */
// Clone ticket schedule js


window.App = window.App || {};
(function ($) {
	"use strict";

	App.Ticketschedule.CloneSchedule = {
		onVisit: function (data) {
			App.Ticketschedule.initEmail();
			App.Ticketschedule.bindEvents();
			App.Ticketschedule.constructScheduleMessage();
			App.Ticketschedule.copyClipboard();
			$('#scheduled_export_name').focus();
			$('.schedule-state').trigger('change');
			$('#email_recipients').val(ticketSchedule.current_user_recipients[0].id).trigger('change');
			App.Ticketschedule.changeFieldLabel('ticket-fields');
			App.Ticketschedule.initToggleFields();
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