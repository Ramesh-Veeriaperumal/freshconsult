define([  
  'jquery',
  'underscore',
  'backbone',  
  'text!templates/settings/canned_reply.html'
], function($,_, Backbone,CannedReplyTemplate){
	var _view = null;
	var cannedReply = Backbone.View.extend({		
	 	render:function(){
	 		$('#right_settings').html(_.template(CannedReplyTemplate,{}));	 
	 			
	 	},
	 	_listeners:function(){
	 		var that = this;
	 	}	 	
	 });

	 if(!_view){_view = new cannedReply;}

	return _view;

});