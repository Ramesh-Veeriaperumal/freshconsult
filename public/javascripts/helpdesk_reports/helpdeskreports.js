/*jslint browser: true, devel: true */
/*global  App */

window.App = window.App || {};
(function ($) {
	"use strict";

	App.Helpdeskreports = {
		URL_MAPPING: {
			'ticket_volume': 'TicketVolume',
			'glance': 'Glance',
			'agent_summary': 'AgentSummary',
			'group_summary': 'GroupSummary',
			'performance_distribution': 'PerformanceDistribution'
		},

		onFirstVisit: function(data) {
			this.onVisit(data);
		},

		onVisit: function(data) {
			var report = window.location.pathname.split('/reports/v2/').last();
			HelpdeskReports.CoreUtil.bindEvents();
			if(this.URL_MAPPING[report]) {
				HelpdeskReports.ReportUtil[this.URL_MAPPING[report]].init();
			}
		},

		onLeave: function(data) {
			var core = HelpdeskReports.CoreUtil;
			core.flushLocals();
			core.flushCharts();
			core.flushEvents();
		}
	}
}(window.jQuery));