RealtimeDashboard.Widgets = RealtimeDashboard.Widgets || {};

RealtimeDashboard.Widgets.TrendCounter = {
	tickets_data : {},
	isGlobalView: false,
	requestData: {},
	isResponder: false,
	constants: {
		endPoint : "/helpdesk/tickets_summary",
	},
	fetchData : function (group_id) {
			var self = this,
				data = {};

			if (this.isGlobalView){
				var groupId = group_id || this.requestData['group_id'];

				data['global'] = true;
				if (groupId != undefined && groupId != "-") {
					data['group_id'] = groupId;
					data['group_by'] = "responder_id";
				}
			}

			this.requestData = data;

			jQuery.ajax({
                data: data,
                url: self.constants.endPoint,
                success: function (response) {
                    self.tickets_data = response.tickets_data;
                    self.parseResponse();
                }
            });
		},
		parseResponse : function () {
			var self = this;
			this.renderTicketSummary();
			self.core.controls.enableGroupSelection();
		},
		renderTicketSummary: function () {
			var self = this;
			if (!jQuery.isEmptyObject(this.tickets_data.ticket_trend)) {
				self.core.Utils.renderTemplate('#ticket-summary',
				'app/realtime_dashboard/template/ticket_summary', this.tickets_data.ticket_trend);
			}
		},
		bindEvents : function() {
			var self = this;
			jQuery(document).on('group_change',function(event) {
				self.fetchData(event.group_id);
			});
		},
		init : function() {
			var self = this;
			self.core = RealtimeDashboard.CoreUtil;
			self.fetchData();
			self.bindEvents();
			self.isGlobalView = jQuery('#realtime-dashboard-content').data('widgetType');
		}
}