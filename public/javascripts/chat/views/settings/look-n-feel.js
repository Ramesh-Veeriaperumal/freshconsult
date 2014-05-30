define([  
  'jquery',
  'underscore',
  'backbone',  
  'text!templates/settings/look-n-feel.html'
], function($,_, Backbone,lookandfeelTemplate){
	var _view = null;
	var lookandfeelView = Backbone.View.extend({		
	 	render:function(){
	 		$('#right_settings').html(_.template(lookandfeelTemplate,{}));	 
	 		this._listeners();	
	 	},
	 	_listeners:function(){
	 		var that = this;
	 		$('.red_theme').click(function(){
				$('.chat_fc_header, #chat-container').removeClass().addClass('chat_fc_header red');
			});

			$('.blue_theme').click(function(){
				$('.chat_fc_header, #chat-container').removeClass().addClass('chat_fc_header blue');
			});

			$('.green_theme').click(function(){
				$('.chat_fc_header, #chat-container').removeClass().addClass('chat_fc_header green');
			});

			$('.orange_theme').click(function(){
				$('.chat_fc_header, #chat-container').removeClass().addClass('chat_fc_header orange');
			});

			$('.teel_theme').click(function(){
				$('.chat_fc_header, #chat-container').removeClass().addClass('chat_fc_header teel');
			});

			$('.gray_theme').click(function(){
				$('.chat_fc_header, #chat-container').removeClass().addClass('chat_fc_header gray');
			});
	 	}
	 });
	 if(!_view){_view = new lookandfeelView;}

	return _view;

});