define([  
  'jquery',
  'underscore',
  'backbone',  
  'text!templates/settings/greeter.html'
], function($,_, Backbone,GreeterTemplate){
	var _view = null;
	var greeter = Backbone.View.extend({		
	 	render:function(){
	 		$('#right_settings').html(_.template(GreeterTemplate,{}));	 
	 			
	 	},
	 	_listeners:function(){
	 		var that = this;
	 	}	 	
	 });

	 if(!_view){_view = new greeter;}

	return _view;

});