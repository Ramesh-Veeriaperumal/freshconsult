define([	
	'backbone', 
	'underscore', 
	'customer/views/main'
	], 
function(Backbone, _, mainView){
	var that;
	var Router = Backbone.Router.extend({
		initialize: function(){
			this.mainView = mainView;
			// this.client = client;
			that = this;
			Backbone.history.start();
		},
		routes: {
			'': 'home'
		},
		'home': function(){			
			this.mainView.render();
		}
	});
	
	return Router;
});