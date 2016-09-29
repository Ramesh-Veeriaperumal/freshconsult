/*jslint browser: true, devel: true */
/*global  App:true, mixpanel */

window.App = window.App || {};
(function ($) {
	"use strict";
	
	App.Metrics = {
		//Namespaces are being used here. Not the urls.
		//Namespace is in the format of Controller/Action
		
		allowOnly: [
			'admin/portal/index',
			'discussions/index',
			'discussions/your_topics'
		],
		allowLike: [
		],
		allowed: function () {
			var i;
			if (this.allowOnly.indexOf(App.namespace) > -1) {
				return true;
			}
			
			for (i = 0; i < this.allowLike.length; i = i + 1) {
				if (this.allowLike[i].test(App.namespace)) {
					return true;
				}
			}
		}
	};
	
	App = $.extend(true, App, {
		previous_namespace: null,
		track: function (name, data) {
			if (typeof (mixpanel) === 'undefined') {
				return false;
			}
			
			data = data || {};
			mixpanel.track(name, data);
			return true;
		},
		trackPageView: function () {
			if (typeof (mixpanel) === 'undefined') {
				return false;
			}

			if (!App.Metrics.allowed()) {
				return false;
			}
			mixpanel.track(App.namespace, {
				'referrer': App.previous_namespace
			});
			
			return true;

		},
		startMetrics: function () {
			App.trackPageView();
			
			//Binding listeners
			$(document).on('pjax:beforeSend', function () {
				App.previous_namespace = App.namespace;
			});
			
			$(document).on('pjax:end', function (ev) {
				App.trackPageView();
			});
			
			$('body').on('click.app_metrics', '[data-track]', function (ev) {
				var $this = $(this);
				App.track($this.data('track'), $this.data('eventData'));
			});
		}
	});
}(window.jQuery));

window.jQuery(function () {
	"use strict";
	if (typeof (mixpanel) !== 'undefined') {
		App.startMetrics();
	}
});