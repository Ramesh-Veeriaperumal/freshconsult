RealtimeDashboard.Widgets = RealtimeDashboard.Widgets || {};

RealtimeDashboard.Widgets.Csat = {
	constants : {
		endPoint : '/helpdesk/dashboard/survey_info'
	},
	fetchData : function() {
		var self = this;
		var opts = {
            url: self.constants.endPoint,
            success: function (response) {
                self.parseResponse(response['survey']);
            }
        };
        self.core.makeAjaxRequest(opts);
	},
	parseResponse : function(response) {
		var self = this;
		//jQuery(' [rel=sent]').html(response['survey_sent']);
		jQuery(' [rel=responded]').html(response['survey_responded']);
		if(!jQuery.isEmptyObject(response['results'])){
			jQuery(' [rel=positive]').html(response['results']['Positive'] + '%');
			jQuery(' [rel=negative]').html(response['results']['Negative'] + '%');
			jQuery(' [rel=nuetral]').html(response['results']['Neutral'] + '%');
		}
	},
	bindEvents : function() {

	},
	showTimeStamp : function() {
		var self = this;
		var date = new Date();
		var str = I18n.t('helpdesk.realtime_dashboard.this_month');
		jQuery('.csat_widget [rel=timestamp]').html(str);
	},
	init : function() {
		var self = this;
		self.core = RealtimeDashboard.CoreUtil;
		self.fetchData();
		self.bindEvents();
		self.showTimeStamp();
	}
}	