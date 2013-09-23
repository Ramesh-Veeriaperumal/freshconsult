define([  
  'jquery',	
  'underscore',
  'backbone',  
  'text!templates/settings/add_agents.html'
], function($,_, Backbone,AddAgentsTemplate){
	var _view = null;
	var AddAgentsView = Backbone.View.extend({		
	 	render:function(){
	 		$('#right_settings').html(_.template(AddAgentsTemplate,{}));	 
	 			
	 	},
	 	_listeners:function(){
	 		var that = this;
	 	}	 	
	 });

	 if(!_view){_view = new AddAgentsView;}

	return _view;

});