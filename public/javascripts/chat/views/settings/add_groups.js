define([  
  'jquery',	
  'underscore',
  'backbone',  
  'text!templates/settings/add_groups.html'
], function($,_, Backbone,AddGroupsTemplate){
	var _view = null;
	var AddGroupsView = Backbone.View.extend({		
	 	render:function(){
	 		$('#right_settings').html(_.template(AddGroupsTemplate,{}));	 
	 			
	 	},
	 	_listeners:function(){
	 		var that = this;
	 	}	 	
	 });

	 if(!_view){_view = new AddGroupsView;}

	return _view;

});