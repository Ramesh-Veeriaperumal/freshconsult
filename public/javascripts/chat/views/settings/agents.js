define([  
  'jquery',
  'underscore',
  'backbone',  
  'text!templates/settings/agents.html'
], function($,_, Backbone,AgentsTemplate){
	var _view = null;
	var AgentsView = Backbone.View.extend({		
	 	render:function(){
	 		$('#right_settings').html(_.template(AgentsTemplate,{}));	 
	 			
	 	},
	 	_listeners:function(){
	 		var that = this;
	 	}	 	
	 });

	 if(!_view){_view = new AgentsView;}

	return _view;

});