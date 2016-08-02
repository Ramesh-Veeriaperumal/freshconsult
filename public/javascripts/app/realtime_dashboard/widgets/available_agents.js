RealtimeDashboard.Widgets = RealtimeDashboard.Widgets || {};

RealtimeDashboard.Widgets.Available_agents = {
	widgetName : 'available_agents',
	endPoint : '',
	fetchData : function() {
		var self = this;

		var opts = {
            url: self.endPoint,
            type: 'GET',
            contentType: 'application/json',
            success : function(resp) {
            	//process resp
            }
	     }
	     self.core.makeAjaxRequest(opts);
	},
	bindEvents : function() {
		var self = this;

		if(jQuery.inArray(self.widgetName,RealtimeDashboard.auto_refresh) != -1) {
			jQuery(document).on('refresh',function() {
				self.fetchData();
			});
		}
	},
	init : function() {
		var self = this;
		self.core = RealtimeDashboard.CoreUtil;
		self.fetchData();
	}
}