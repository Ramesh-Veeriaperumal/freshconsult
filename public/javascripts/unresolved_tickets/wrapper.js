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
				var localStorage_obj = JSON.parse(window.localStorage.getItem('unresolved-tickets-filters'));
				if(!shared_ownership_enabled && localStorage_obj.group_by.indexOf('internal_') > -1){
					var defaultParam = {group_by: "group_id"};
					UnresolvedTickets.init(defaultParam);
				}else{
					UnresolvedTickets.hasLocalData(localStorage_obj);
				}
				
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