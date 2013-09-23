define([
  'text!templates/settings.html',
  'views/settings/look-n-feel',
  'views/settings/behaviour_text',
  'views/settings/greeter',
  'views/settings/canned_reply',
  'views/settings/agents',
  'views/settings/add_agents',
  'views/settings/groups',
  'views/settings/add_groups',

], function(settingsTemplate,lookAndFeel,behaviourText,greeter,cannedReply,Agents,AddAgentsView,GroupsView,AddGroupsView){
	var $ = jQuery;
	var _view = null;
	var SettingsView = Backbone.View.extend({		
		activeItem:null,
	 	render:function(){
	 		this.activeItem = null;
	 		$('.container-fluid').html(_.template(settingsTemplate,{site_id:SITE_ID,web_root:WEB_ROOT}));	
	 		this._listeners(); 		
	 	},
	 	_listeners:function(){
	 		var that = this;
	 		$('#look-n-feel').click(function(){
	 			lookAndFeel.render();
	 			if(that.activeItem){
	 				that.activeItem.removeClass('active');
	 			}
	 			that.activeItem = $(this).addClass('active');
	 		});

	 		$('#behaviour_text').click(function(){
	 			behaviourText.render();
	 			if(that.activeItem){
	 				that.activeItem.removeClass('active');
	 			}
	 			that.activeItem = $(this).addClass('active');
	 		})

	 		$('#greeter').click(function(){
	 			greeter.render();
	 			if(that.activeItem){
	 				that.activeItem.removeClass('active');
	 			}
	 			that.activeItem = $(this).addClass('active');
	 		})

	 		$('#canned_reply').click(function(){
	 			cannedReply.render();
	 			if(that.activeItem){
	 				that.activeItem.removeClass('active');
	 			}
	 			that.activeItem = $(this).addClass('active');
	 		})

	 		$('#agents').click(function(){
	 			Agents.render();
	 			if(that.activeItem){
	 				that.activeItem.removeClass('active');
	 			}
	 			that.activeItem = $(this).addClass('active');

	 			$('#add_agent').click(function(){
	 				AddAgentsView.render();
	 			})
	 		})

	 		$('#groups').click(function(){
	 			GroupsView.render();
	 			if(that.activeItem){
	 				that.activeItem.removeClass('active');
	 			}
	 			that.activeItem = $(this).addClass('active');
	 			$('#add_group').click(function(){
	 				AddGroupsView.render();
	 			})
	 		})
	 	}	 	
	 });

	 if(!_view){_view = new SettingsView;}

	return _view;

});