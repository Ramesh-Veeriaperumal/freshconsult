RealtimeDashboard.Widgets = RealtimeDashboard.Widgets || {};

RealtimeDashboard.Widgets.Due = {
	constants : {
		endPoint : '/helpdesk/dashboard/due_today'
	},
	container_class : '.due_widget',
	tickets_list_base_url : '/helpdesk/tickets/filter/due_today',
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
	setTicketPageUrl : function() {
		var self = this;
		var href = self.tickets_list_base_url + '?agent=0';
		jQuery('[rel=due_link]').attr('href',href);
	},
	parseResponse : function(response) {
		var self = this;
		var val = response['due_today'].value;
		if(val > 9999) {
			jQuery(' [rel=due] .value').html(self.core.shortenLargeNumber(val,1));
			jQuery("[rel=due] .value").twipsy({
                html : true,
                placement : "above",
                title : function() { 
                    return val;
            }});
		} else {
			jQuery(' [rel=due] .value').html(val);
		}
		
		//self.core.hideLoader(self.container_class);
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