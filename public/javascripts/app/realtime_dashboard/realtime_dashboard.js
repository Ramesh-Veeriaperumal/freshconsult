/*jslint browser: true, devel: true */
/*global  App:true */

window.App = window.App || {};
window.App.Channel = window.App.Channel || new MessageChannel();

(function ($) {
	"use strict";

	App.RealtimeDashboard = {
		onFirstVisit: function (data) {
			this.onVisit(data);
		},
		onVisit: function (data) {

			this.bindHandlers();

			if(App.namespace != "helpdesk/dashboard/index") {
				return false;
			}

			RealtimeDashboard.CoreUtil.init();
		},
		onLeave: function (data) {
			RealtimeDashboard.CoreUtil.destroy();
		},
		bindHandlers: function () {
			this.startWatchRoutes();
		},

		startWatchRoutes: function () {
			var isIframe = (window !== window.top);
			if (isIframe) {
				var prefix = '/admin';
				var emberizedPath = location.pathname.indexOf('helpdesk') ? prefix + location.pathname.replace('helpdesk/', '') : prefix + location.pathname;
				window.App.Channel.port1.postMessage({ action: "update_iframe_url", path: emberizedPath });
			}
		},
	};
}(window.jQuery));
