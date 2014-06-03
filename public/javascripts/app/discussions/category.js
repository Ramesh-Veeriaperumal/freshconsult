/*jslint browser: true, devel: true */
/*global  App, $H, delay */

window.App = window.App || {};
window.App.Discussions = window.App.Discussions || {};
(function ($) {
	"use strict";

	App.Discussions.Category = {
		onVisit: function () {
			App.Discussions.Reorder.start();
		},

		onLeave: function () {
			App.Discussions.Reorder.leave();
		}
	};
}(window.jQuery));
