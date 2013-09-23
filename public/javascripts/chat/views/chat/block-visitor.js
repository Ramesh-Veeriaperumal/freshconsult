define([
  'text!templates/chat/block-visitor.html'  
], function(blockTemplate){  
	var $ = jQuery;
	var blockView = Backbone.View.extend({				
		isOpen: false,
		render:function(chat,blockCallback){			
			var that = this;
			if(!that.isOpen){
				that.isOpen = true;
				$('body').append(_.template(blockTemplate,{chat:chat}));
				$('.closeDialog, .cancelBtn').on('click', function(){
					that.closeView(chat);
				});
				$('#block_visitor_btn_'+chat.id).on('click', function(){
						 chat_socket.emit('block visitor',{userName:chat.visitor.userName});
						 chat_socket.once('block visitor', function(visitor){						 		
						 		that.closeView(chat);
						 		chat.visitor = visitor;
						 		blockCallback(chat);
						 });	
				});
			}
		},
		closeView:function(chat){
			$('#block-visitor-'+chat.id).remove();
			this.isOpen = false;
		}
	});
	return 	(new blockView());
});