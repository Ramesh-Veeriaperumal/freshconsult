define([
	'text!templates/dashboard.html',
	'collections/users',
	'views/visitor_list',
	'views/sidebar'
], function(dashboardTemplate,users,visitorsView,sidebarView){
	var $ = jQuery;
	var _view = null;
	var dashboardView = Backbone.View.extend({
		render:function(repeat){
			$("#chat-dashboard").show().html(_.template(dashboardTemplate,{}));
			visitorsView.fetch('no');
			this.listen();
			if(repeat){ this.agentCount(); }
	 	},
	 	listen:function(){
	 		var that = this;
	 		$("#chat_visitors").on('click',function(e){
	 			sidebarView.showDetails(e,'online');
	 		});
	 		$("#chat_archive").on('click',function(e){
	 			sidebarView.showDetails(e,'archive');
	 		});	 		
	 	},
	 	agentCount:function(count){
	 		var count=users.onlineAgents();
	 		$("#online_agent_count,#bar_agents_count").html(count);
	 	}
	});

	if(!_view){_view = new dashboardView;}

	return _view;

});