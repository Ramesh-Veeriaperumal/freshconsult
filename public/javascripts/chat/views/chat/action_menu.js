define([
  'text!templates/chat/action_menu.html',
  'views/chat/transfer_agent',
  'views/chat/block-visitor',
  'views/chat/tag-this' 
], function(menuTemplate,transferView,blockView,tagView){
	var $ = jQuery;
	var menuView = Backbone.View.extend({
		isOpen: false,
		render:function(chat){
			var that = this;
			that.isOpen = true;
			var userAgent = (chat.userAgent) ? JSON.parse(chat.userAgent) : null;
			var actionMenu = $('<div/>');
			actionMenu.attr('id',chat.id+"_action_menu");
			actionMenu.addClass('updateUser');
			actionMenu.html(_.template(menuTemplate,{chat:chat,userAgent:userAgent}));
			$('#'+chat.id+'_user_header').append(actionMenu);
			this._listeners(chat);
		},
		_listeners:function(chat){
			var that = this;
			$("#user-"+chat.id).on('click', function(event){
					event.stopPropagation();
 					$("#"+chat.id+"_action_menu").toggle();
 			});			
			$("#tag-"+chat.id).on('click', function(){
					$("#"+chat.id+"_action_menu").toggle();
					chat_socket.emit('tags exist',{chatid:chat.id});
					chat_socket.once('tags exist',function(data){
						tagView.render(data);
					});
			});
			if(chat.ptype=="agent"){return;}
			$("#transfer-"+chat.id).on('click', function(){
				$("#"+chat.id+"_action_menu").toggle();
				transferView.render(chat);
			});
			$("#block-"+chat.id).on('click', function(){
				if(chat.visitor && chat.visitor.blocked){
					chat_socket.emit('unblock visitor',{userName:chat.visitor.userName, chat_id:chat.id});
					chat_socket.once('unblock visitor', function(visitor){
				 		chat.visitor = visitor;
				 		that._toggleBlockAction(chat);
					});
				}else{
					blockView.render(chat,that._toggleBlockAction);
				}
				$("#"+chat.id+"_action_menu").toggle();
 			});
		},
		_toggleBlockAction:function(chat){
			var block_text = ((chat.visitor.blocked) ? i18n.unblock : i18n.block) + " "+i18n.visitor;
			$("#block-"+chat.id).html(block_text);
		}
	});
	return 	(new menuView());
});