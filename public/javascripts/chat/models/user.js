define([
	'views/chat'
], 
function(ChatView){
	var $ = jQuery;
	var UserModel = Backbone.Model.extend({
		chat:function(){
			var chatId = chatCollection.findByUser(this.get('id'));
			if(chatId!=""){
				availableChat(chatId);
				return;
            }
			if(this.associatedchat){
			   	var chatid = this.associatedchat.id;
			   	var chatTab = $("#tabs-chat-"+chatid);
				if(chatTab && chatTab.length>0){
					if(!($('#tabs-group a[href*="tabs-chat-'+chatid+'"]').parent()
							.hasClass("ui-tabs-selected ui-state-active"))){
						availableChat(chatid);
					}
					return;
				}
			   	chat_socket.emit('join chat',{
		 			id: chatid
				});
				return;
			}	   	
		   	chat_socket.emit('create chat',{
		   		userid: this.get('id'),
		   		name: this.get('username')
		   	});
		},
		map:function(chat){
			this.associatedchat = chat;
		}
	});

	return UserModel;
});