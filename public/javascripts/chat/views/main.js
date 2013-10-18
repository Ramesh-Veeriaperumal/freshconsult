define([
		'models/main',
		'views/client',
		'text!templates/main.html'], 
function(model, client, template){
	var $ = jQuery;
	var View = Backbone.View.extend({
		el: '#main',
		initialize: function(){
			this.model = new model({
				message: 'Hello World'
			});
			this.template = _.template( template, { model: this.model.toJSON() } );
		},
		render: function(){
			client.show();
		}		
	});
	
	return new View();
});
