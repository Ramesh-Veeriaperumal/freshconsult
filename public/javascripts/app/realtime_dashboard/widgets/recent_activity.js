RealtimeDashboard.Widgets = RealtimeDashboard.Widgets || {};

RealtimeDashboard.Widgets.Recent_activity = {
	scrollTopOnLoadMore: function () {
		jQuery("#activityfeed").mCustomScrollbar("scrollTo","-=300");
	},
	bindEvents : function(){
		var self = this;
		jQuery(document).on('#load-more','click',function(){
			self.scrollTopOnLoadMore();
		});
	},
	init : function() {
		jQuery('#Activity').on('remoteLoaded', function(e){
			jQuery(".activityfeed-wrap").mCustomScrollbar();
		});
	}
}