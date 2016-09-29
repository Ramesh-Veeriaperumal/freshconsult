(function(){
	window.RealtimeDashboard = window.RealtimeDashboard || {};

	RealtimeDashboard.persist = {
		key : 'last_visited_snapshot',
		storeOrUpdate : function(name) {
			if (typeof (Storage) !== "undefined") {
				localStorage.setItem(this.key,name);
			}
		},
		getLastVisited : function() {
			if (typeof (Storage) !== "undefined" && localStorage.getItem(this.key) !== null) {
					return localStorage.getItem(this.key);
			} else{
				return false;
			}
		},
		bindEvents : function() {
			var self = this;

			jQuery(document).on("dashboard_visited",function(ev,data){
	        	self.storeOrUpdate(data.type);
	        	self.modifyLink();
	        });
			jQuery(document).ready(function(){
				self.modifyLink();
			});
	        
	        jQuery(document).on('pjax:success', function() {
	        	self.modifyLink();
			});
		},
		modifyLink : function() {
			var type = this.getLastVisited();
			if(type) {
				var href = '/helpdesk/dashboard?view=' + type
				//top nav
				jQuery("[data-tab-name=dashboard] a").prop('href',href);
				jQuery("a[rel='dashboard_link']").prop('href',href);
			}
		},
		init : function() {
			var self = this;
			self.bindEvents();
		}
	}
	RealtimeDashboard.persist.init();
})();