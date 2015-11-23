window.App = window.App || {};
(function ($) {
	"use strict";

	App.Unresolvedtickets = {

		onFirstVisit: function (data) {
			this.onVisit(data);
		},
		onVisit: function (data) {
			UnresolvedTickets.showLoader("full-loader");
			if(window.localStorage.getItem('unresolved-tickets-filters')){
				UnresolvedTickets.hasLocalData();
			}else{
				var defaultParam = {group_by: "group_id"};
				UnresolvedTickets.init(defaultParam);
			}
		},
		onLeave: function (data) {
			UnresolvedTickets.unbindEvents();
		}
	};
}(window.jQuery));