RealtimeDashboard.Widgets = RealtimeDashboard.Widgets || {};

RealtimeDashboard.Widgets.Gamification = {
	Constants: {
		endPoint : "/helpdesk/dashboard/achievements"
	},
	getAchievements: function () {
		var self = this;
		jQuery.ajax({
            url: self.Constants.endPoint ,
            success: function (response) {
            	var badges = self.getBadges(response.badges);
            	var object = {
            		badges: badges,
            		chartData : response
            	}

            	RealtimeDashboard.CoreUtil.Utils.renderTemplate("#achievements", "app/realtime_dashboard/template/achievements", object);
            	setTimeout(function(){
            		self.renderProgresschart(response);
            	},100);
            }
        });
	},
	getBadges: function (badgeIds) {
		var badges = [],
			badgeIds = (badgeIds != "") ? badgeIds.split(',') : "";

		jQuery.each(badgeIds, function(i, val) {
			badges.push(DataStore.get('badges').findById(parseInt(val)));
		})

		return badges;
	},
	renderProgresschart: function (achievementData) {
		
		if(achievementData.points == null || achievementData.points == ""){
			jQuery('#achievementsChart').html("<div class='no_data_to_display text-center muted'><i class='ficon-no-data fsize-48'></i></div>");
		} else {
			var series = [];
			var obj = {
				name : achievementData.current_level_name,
				data : [],
				zones : [{
					color : '#6c6c6c'
				}]
			};
			obj.data.push(achievementData.points);
			series.push(obj);
			var opts = {
				max : achievementData.points + achievementData.points_needed,
				series : series,
				container : "achievementsChart"
			}
			progressGauge(opts);
		}
	},
	bindEvents : function(){
		var self = this;
		jQuery('.game-tabs li').on('click',function() {
			var clicked = this;
			var selected_tab_id = jQuery(clicked).find('a').attr('id');
			if(selected_tab_id == 'requester-tab') {
				//self.getAchievements();
			}
		});
	},
	init : function() {
		var self = this;
		self.getAchievements();
		self.bindEvents();
	}
}