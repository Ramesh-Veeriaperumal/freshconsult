RealtimeDashboard.Widgets = RealtimeDashboard.Widgets || {};

RealtimeDashboard.Widgets.OverDue = {
	constants : {
		endPoint : '/helpdesk/dashboard/overdue'
	},
	container_class : '.overdue_widget',
	tickets_list_base_url : '/helpdesk/tickets/filter/overdue',
	fetchData : function() {
		var self = this;

		//self.core.showLoader(self.container_class);
		var opts = {
            url: self.constants.endPoint,
            success: function (response) {
                self.parseResponse(response);
            }
        };
        self.core.makeAjaxRequest(opts);
	},
	parseResponse : function(response) {
		var self = this;
		var val = response['overdue'].value;
		if(val > 9999) {
			jQuery('[rel=overdue] .value').html(self.core.shortenLargeNumber(val,1));
			jQuery("[rel=overdue] .value").twipsy({
                html : true,
                placement : "above",
                title : function() { 
                    return val;
            }});
		} else {
			jQuery('[rel=overdue] .value').html(val);	
		}
		//self.core.hideLoader(self.container_class);
	},
	setTicketPageUrl : function() {
		var self = this;
		var href = self.tickets_list_base_url + '?agent=0';
		jQuery('[rel=overdue_link]').attr('href',href);
	},
	bindEvents : function() {

	},
	init : function() {
		var self = this;
		self.core = RealtimeDashboard.CoreUtil;
		self.fetchData();
		self.setTicketPageUrl();
		self.bindEvents();
	}
}