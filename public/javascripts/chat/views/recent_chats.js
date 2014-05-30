define([
  'text!templates/recent_chats.html'
], function(recentChatTemplate){
	var $ = jQuery;
	var _view = null;
	var recentView = Backbone.View.extend({
	 	render:function(){
	 		var recentChats = $('<div>');
				recentChats.attr('id','recent_container');
				$(document.body).append(recentChats);
	 		this._listeners();
	 	},
	 	_listeners:function(){
	 		var that = this;
	 		$("#bar_recent_list").on('click', function(event){	
	 			  event.stopPropagation();
	 			  var recentCon = $("#recent_container");
	 			  if(recentCon.is(':visible')){
	 					recentCon.slideToggle('slow');
	 				}else{
	 					recentCon.html("");
	 					chat_socket.emit('recent request',{userid:CURRENT_USER.id});
	 				}
	 		});
	 	},
	 	update:function(chats){	 		
	 		var html = '';	 		
	 		chat_socket.on('recent message',function(data){	 						 					
				var message = "Empty";
				if(data.msg){message=data.msg.msg;}
				message = (message.length < 35) ? message : message.substr(0,35)+"..."; 					
				$('#'+data.chatid+"_last_msg").html(message);	
	 		});
	 		var chatLength = chats.recent.length;
	 		for (var i=0; i < chatLength; i++) {	 			
	 			if((i%2)==0){
	 				classname = 'guest';
	 			}
	 			else{
	 				classname = 'self';
	 			}
	 			this.createRow(chats.recent[i],classname);
	 		}
	 		if(chatLength==0){
	 			this.empty();
	 		}
	 		$("#recent_container").css('bottom',$('#sidebar').height()).slideToggle('slow');
	 	},
	 	createRow:function(chat,classname){
	 		var recent_row = $('<div>');
	 		var dateStr = chat.updatedAt;
	 		if(!dateStr){
	 			dateStr = chat.createdAt;
	 		}
	 		var date = new Date(dateStr);

	 		recent_row.html(_.template(recentChatTemplate,{chat:chat,date:date.toString("hh:mm tt")}));
	 		recent_row.attr('id','recent_chats_'+chat.id);
	 		recent_row.addClass('recent_chats '+classname);
			$('#recent_container').append(recent_row);
	 		recent_row.on('click',function(chatid){
	 			return function(){
					if($("#tabs-chat-"+chatid).length>0){
						availableChat(chatid);
						return;
					}
	 				chat_socket.emit('join chat',{
	 					id: chatid
					});
				};
 			}(chat.id));
			chat_socket.emit('recent message',{id:chat.id});
	 	},
	 	empty:function(){
	 		var emptyDiv = $("<div/>").addClass("chat_recent_empty");
	 		emptyDiv.html(i18n.chat_recent_empty_tip);
	 		$('#recent_container').append(emptyDiv);
	 	}
	 });

	 if(!_view){_view = new recentView;}

	return _view;

});