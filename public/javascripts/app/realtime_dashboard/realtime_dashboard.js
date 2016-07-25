/*jslint browser: true, devel: true */
/*global  App:true */

window.App = window.App || {};

(function ($) {
	"use strict";

	App.RealtimeDashboard = {
		onFirstVisit: function (data) {
			this.onVisit(data);
		},
		onVisit: function (data) {

			if(App.namespace != "helpdesk/dashboard/index") {
				return false;
			}

			RealtimeDashboard.CoreUtil.init();
		},
		onLeave: function (data) {
			RealtimeDashboard.CoreUtil.destroy();
		}
	};
}(window.jQuery));
