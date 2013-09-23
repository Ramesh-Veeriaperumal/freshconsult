define([  
  'jquery',
  'underscore',
  'backbone',  
  'text!templates/settings/groups.html'
], function($,_, Backbone,GroupsTemplate){
	var _view = null;
	var GroupsView = Backbone.View.extend({		
	 	render:function(){
	 		$('#right_settings').html(_.template(GroupsTemplate,{}));	 
	 			
	 	},
	 	_listeners:function(){
	 		var that = this;
	 	}	 	
	 });

	 if(!_view){_view = new GroupsView;}

	return _view;

});