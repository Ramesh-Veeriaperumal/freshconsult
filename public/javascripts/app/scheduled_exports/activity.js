window.App = window.App || {};
(function ($) {
	"use strict";

	App.Ticketschedule.EditActivity = {
		onVisit: function (data) {
			App.Ticketschedule.copyClipboard();
      App.Ticketschedule.bindToggleEvents();
			$('#scheduled_activity_export_name').focus();
		},

		onLeave: function (data) {
			if (this.current_module !== '') {
				this.current_module = '';
				App.Ticketschedule.unbindEvents();
			}
		}
	}
}(window.jQuery));
