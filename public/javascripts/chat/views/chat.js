//Filename: chat.js
define([
  'views/tab',  
  'text!templates/chat.html',
  'text!templates/message.html',
  'text!templates/visitor_info_link.html',
  'text!templates/chat_header.html',
  'views/visitor_details',
  'collections/chats',
  'views/url_parser',
  'views/chat/action_menu',
  'views/notifier',
  'views/visitor_details',
  'views/chat/ticket_options'
], function(tabView,chatTemplate,messageTemplate,infoTemplate,headerTemplate,visitorView,ChatCollection,urlParser,actionMenu,notifierView,visitorDetails,ticketOptions){
	var $ = jQuery;
	var ChatView = Backbone.View.extend({
		render:function(chat,msg){

			if(!window.chatCollection){
				window.chatCollection = new ChatCollection();
			}

			var that = this;
			if(!chat){
				return;
			}

			this.messageTemplate = messageTemplate;
			this.infoTemplate = infoTemplate;
			this.tab = tabView;
			chat.view = this;
			chat = window.chatCollection.addNew(chat);

			if(chat.ptype=="agent"){
				if(CURRENT_USER.id != chat.userId){
					_.each(userCollection.models, function(user) {
						if (chat.userId == user.get('id')){
						  	chat.title = user.get('name');
						}
					});
				}
			}else{
				var visitorChats = chatCollection.models;
				for(var v=0;v<visitorChats.length;v++){
					if((visitorChats[v].transfer && visitorChats[v].transfer>0) && chat.id != visitorChats[v].id && visitorChats[v].visitor.id == chat.visitor.id){
						visitorChats[v].view.close(visitorChats[v]);
					}
				}
			}

			tabView.render(function(){
				localStore.store('chat',chat.id);
				if($("#tabs-chat-"+chat.id).length>0){
					return;
				}
				$("#tabs").jtabs("add","#tabs-chat-"+chat.id,chat.title);
				$("#tabs-chat-"+chat.id).removeClass("ui-tabs-hide");
				$('#tabs-group a[href*="tabs-chat-'+chat.id+'"]').parent()
						.addClass("ui-tabs-selected ui-state-active");
				$("#tabs-chat-"+chat.id).html(_.template(chatTemplate,{id:chat.id}));
				nodeLength = $('#tabs').find('ul').children().length;
				$("#tabs-chat-"+chat.id).attr('rel',nodeLength);

				if(chat.title.length>20){
					chat.changeTitle(chat.title);
				}
				tabPosition();

				// fix the classes
				$( ".tabs-bottom .ui-tabs-nav, .tabs-bottom .ui-tabs-nav > *" )
					.removeClass( "ui-corner-all ui-corner-top" )
					.addClass( "ui-corner-bottom" );

				// move the nav to the bottom
				$( ".tabs-bottom .ui-tabs-nav" ).appendTo( ".tabs-bottom" );

				$("#msg-box-"+chat.id).on("keyup",function(e){
					if(e.keyCode==13 && !e.shiftKey){
						e.preventDefault();
						var value = $.trim($(this).val());
						if(value != ""){
							chat.send(that.escapeHtml($(this).val()));
						}
						$(this).val("");
						if(chat.triggerTypeTimer){
							clearTimeout(chat.triggerTypeTimer);
							chat.triggerTypeTimer = null;
						}
					}else if(!that.isIgnoreKey(e.keyCode)){
						chat.typing();
					}
				});

				tabOverflow(chat.id);
				if(chat.ptype=="agent"){
					var opponentId = (CURRENT_USER.id == chat.userId) ? chat.participants[0].userId : chat.userId;
					if(userCollection.get(opponentId).get('status')){
						that.changeStatus(chat.id,'online');
					}
					if(CURRENT_USER.id==chat.userId){
						$('#input-box-'+chat.id).css('background-image','url(/users/'+chat.participants[0].userId+'/profile_image)');
					}else{
						$('#input-box-'+chat.id).css('background-image','url(/users/'+chat.userId+'/profile_image)');
					}
				}else{
					if(!chat.closed){that.changeStatus(chat.id,'online')};
					$('#input-box-'+chat.id).css('background-image','url(/images/fillers/profile_blank_thumb.gif)');
				}
				if(msg && msg.prev_chat){
					$('li.ui-state-active').find('a:first-child').trigger('click');
					$('#tabs-group a[href*="'+msg.prev_chatid+'"]').parent().find('a:first-child').trigger('click');
					that.blink(chat.id);
				}
				that.header(chat);
				chat.transcript();
				that._listeners(chat);
			});
		},
		isIgnoreKey:function(keyCode){
			var keys = [224,9,18,17,16,27,37,38,39,40];
			return ($.inArray(keyCode,keys)!=-1);
		},
		header:function(chat){
			var userAgent = null;
			userAgent = (chat.userAgent) ? JSON.parse(chat.userAgent) : null;
			$('#chat-'+chat.id).before(_.template(headerTemplate,{chat:chat,userAgent:userAgent}));
			actionMenu.render(chat);
		},
		blink:function(chatId){
			var chatTab = $('#tabs-group a[href*="tabs-chat-'+chatId+'"]')
			  chatTab.addClass("blink_background")
              chatTab.find('span').effect("pulsate", {times:3}, 1000);
		},
		updateTranscript:function(data){
			window.chatCollection.updateTranscript(data);
		},
		update:function(msg){
			window.chatCollection.updateMessage(msg);
			if(CURRENT_USER.id != msg.userId){
				soundManager.play('new_msg');
				notifierView.scroll(msg);
				if($("#tabs-chat-"+msg.chatId).hasClass("ui-tabs-hide")){
					this.blink(msg.chatId);
				}
			}
		},
		_listeners:function(chat){
			var that = this;
			$("#visitor-"+chat.id).on('click', function(){
				visitorView.render(chat);
			});
			$("#visitorInfo-"+chat.id).add(".visitorGeo").on('mouseover', function(){
				$(".visitorGeo").show();
				$("#visitorInfo-"+chat.id).addClass('selected');
			});
			$("#visitorInfo-"+chat.id).add(".visitorGeo").on('mouseout', function(){
				$(".visitorGeo").hide();
				$("#visitorInfo-"+chat.id).removeClass('selected');
			});
			$("#closeChat-"+chat.id).on('click', function(){
				that.close(chat);
			});
			$("#minChat-"+chat.id).on('click', function(){
				$('li.ui-state-active').find('a:first-child').trigger('click');
			});
			$('#tabs-group a[href*="tabs-chat-'+chat.id+'"]').on('click', function(){
				$('#tabs-group a[href*="tabs-chat-'+chat.id+'"]').removeClass("blink_background");
			});
			$("#chat-messages-inner-"+chat.id).on('click', 'a[class$="_info_link"]', function(id){
				return function(){
					var data = $(this).parent();
					var mail = data.attr('data-mail');
					var phone = data.attr('data-phone');
					visitorDetails.render(chat, {mail:mail, phone:phone});
				}
			}(chat.id));
		},
		close:function(chat){
			if(!chat.closed && chat.ptype!="agent"){chat_socket.emit('chat close',{chat:chat.id});}
			else{
				this.closeWindow(chat);
			}
		},
		closeWindow:function(chat){
           var triggerObj = $('#tabs-group li.ui-state-active').find('a:last-child');
           triggerObj.trigger('click');
           window.chatCollection.remove(chat);
           localStore.remove("chat",chat.id);
        }, 
		typingStatus:function(chat,data){
			$("#status-"+chat.id).html(data.name+" "+(IS_TYPING ?  IS_TYPING : i18n.typing_message)).show();
		},
		clearTypingStatus:function(chat){
			$("#status-"+chat.id).html("").hide();
		},
		status:function(data){
			var that = this;
			var chats = chatCollection;
			_.each(chats.models, function(chat) {
				var id = "";
				if(chat.visitor){
					id = chat.visitor.userName;
				}else{
					id = chat.participants[0].userId;
				}
				
				if((id == data.id) && !(chat.transfer && chat.transfer>0)){
					var chatId = chat.id;
					var disconnect_msg = $('#visitor_disconnect_'+chatId);
					if(disconnect_msg.length>0){
						disconnect_msg.remove();
					}					
					var inner = $('#chat-messages-inner-'+chatId);
					if(inner.length>0){
						inner.append("<p class='chat-msginfo' id='visitor_disconnect_"+chatId+"'>"+i18n.visitor_disconnect_msg+"</p>");
						var container = $('#chat-messages-'+chatId);
						container.animate({scrollTop:inner.height()},200);
					}
					that.changeStatus(chatId,"offline");
				}
			});
		},
		transfer:function(data){
			var chatId = data.chatId;
			var inner = $('#chat-messages-inner-'+chatId);
			if(inner.length>0){
				inner.append("<p class='chat-msginfo'>Visitor transfer accepted</p>");
				var container = $('#chat-messages-'+chatId);
				container.animate({scrollTop:inner.height()},200);
			}
			$("#msg-box-"+chatId).prop('disabled',true);
		},
		ignored:function(data){
			var chatId = data.chatId;
			var chat = chatCollection.get(chatId);
			chat.transfer = 0;
			var inner = $('#chat-messages-inner-'+chatId);
			if(inner.length>0){
				inner.append("<p class='chat-msginfo'>Transfer request timed out</p>");
				var container = $('#chat-messages-'+chatId);
				container.animate({scrollTop:inner.height()},200);
			}
		},
		agentStatus:function(data){
			var that = this;
			var status = "offline";
			var users = data.users;
			if(data.status == 1){status = "online";}
			for(var m = 0; m < users.length; m++){
				var user = userCollection.get(users[m].userId);								
				if(user){
					if(user.get('id')!=CURRENT_USER.id){
						user.once({'change:status' : function(){
							var count=userCollection.onlineAgents();
					 		$("#online_agent_count,#bar_agents_count").html(count);
						}});						
						user.set('status',parseInt(data.status));
						var statusObj = $("#"+users[m].userId+"_status");
						statusObj.removeClass(statusObj.className);
						statusObj.addClass("status "+status);						
						if(window.chatCollection){
							_.each(chatCollection.models, function(chat) {
								if((users[m].userId == chat.participants[0].userId) || (users[m].userId==chat.userId)){
									that.changeStatus(chat.id,status);
								}
							});
						}
					}					
				}
			}
		},
		changeStatus:function(chatId,status){
			var statusObj=$('#tabs-group a[href*="'+chatId+'"]').parent().find('span:nth-child(2)')
			$('#tabs-group a[href*="'+chatId+'"]').parent().find('span:nth-child(2)')
				.removeClass(statusObj.className)
				.addClass(status);
			if(status=='offline'){
				$('#transfer-'+chatId).hide();
			}
		},
		escapeHtml:function(string) {
			var entityMap = {
				"&": "&amp;",
				"<": "&lt;",
				">": "&gt;",
				'"': '&quot;',
				"'": '&#39;'
			};
			return String(string).replace(/[&<>"']/g, function (s) {
				return entityMap[s];
			});
		}
	});
  return new ChatView();
});