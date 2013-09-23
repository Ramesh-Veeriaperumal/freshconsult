//Filename: chat.js
define([  
  'underscore', 
  'backbone',
  'cookies'
], function(_, Backbone,Cookies){
	var ChatView = Backbone.View.extend({
		id:FRESH_CHAT_ID,
		type:"site",
		greet:'',
		wait:'',
		render:function(chat,msg){
			var that = this;
			if(!chat){
				return;
			}
			// if(msg){
			// 	this.update(msg);
			// }
		},
		send:function(data){
			if(!this.id){return;}
			var that = this;
			var userName = $.cookie('fc_vname');
			if(userName == null){
				userName = window.userId;
			}
			if(this.type!="site"){
				chat_socket.emit("my msg",{
					id: that.id,
					msg: data.msg,
					username: userName,
					photo:"/images/fillers/profile_blank_thumb.gif"
				});
			}else{
				if(data.prefrm==undefined || data.prefrm!="s"){
					this.update({
						name:"Me",
						msg:data.msg
					});
				}
				data.name = userName;
				chat_socket.emit("visitor ping",data);
			}
		},
		update:function(msg){
			var inner = $('#fc_chat_messagewindow');
			this.show();
			if(inner.length>0){
				inner.append(this.parseMessage(msg));
				this.clearTyping();
				inner.scrollTop(inner.get(0).scrollHeight);
				return;
			}
		},
		show:function(){
			clearTimeout(this.greet);
			$("#fc_chat_container").show('slow');
			$("#fc_chat_symbol").html("&#9660;");
			$("#fc_chat_title").html(FRESH_CHAT_SETTING.maximized_title);
			if($(".fc_pre-form").is(":visible")){
				$(".fc_pre-form").hide();
				$("#fc_chat_window").show();
			}
			$("#fc_chat_inputcontainer").focus();
		},
		parseURL:function(msg){
			var linkRegExp  = /((href|src)=["'])?(((https?:\/\/[^(www\.)])|(https?:\/\/www\.))([a-z0-9](([a-z0-9_\-\.]*)(\.[a-z]{2,3}(\.[a-z]{2}){0,2}([^( <)]*)))))/gi;
			var WWWlinkRegExp  = /([^\/])((www\.)([a-z0-9](([a-z0-9_\-\.]*)(\.[a-z]{2,3}(\.[a-z]{2}){0,2}([^( <)|(https?:\/\/)]*)))))/gi;
			msg = msg.replace(linkRegExp, function($0, $1){
				return ($1=="" || $1==undefined) ? "<a href='"+$0+"' target='_blank'>"+$0+"</a>" : $0;
			});
			msg = msg.replace(WWWlinkRegExp, function($0, $1, $2){
				return $1+"<a href='http://"+$0+"' target='_blank'>"+$0+"</a>";
			});
			return msg;
		},
		parseMessage:function(msg){
			var time = new Date();
			var hours = time.getHours();
			var minutes = time.getMinutes();
			if(hours < 10) hours = '0' + hours;
			if(minutes < 10) minutes = '0' + minutes;

			var noname = '';
			var name = msg.name;
			if(!msg.userId){
				name = "Me";
				msg.class = 'fc_self';
			}else{
				var check = msg.userId.search('visitor');
				if(check < 0){
					msg.class = 'fc_guest';
				}else{
					msg.class = 'fc_self';
					name = "Me";
				}
			}
			if(msg.type && msg.type=="welcome"){
				noname = "fc_msg-noname";
				name = "";
			}

			var photo;
			if(msg.photo && msg.class == "fc_guest"){
				photo = WEB_ROOT+msg.photo;
			}else{
				photo = WEB_ROOT+"/images/fillers/profile_blank_thumb.gif";
			}
			msg.msg = this.parseURL(msg.msg);
			var html = '<p class="'+msg.class+' clearfix"><img src="'+photo+'" alt="" />'
						+'<span class="fc_msg-block"><b>'+name+'</b> <span class="fc_time">'+hours+':'+minutes+'</span>'
						+'<span class="fc_msg '+noname+'">'+msg.msg+'</span></span></p>';
			return html;
		},
		updateName:function(data){
			$.cookie('fc_vname',data.name);
			window.userName = data.name;
		},
		blockVisitor:function(){
			this.id=null;
		},
		unblockVisitor:function(data){
			this.id=data.id;
		},
		waitMsg:function(){
			clearTimeout(this.wait);
		},
		closeChat:function(data){
			this.type="site";
			if($("#fc_chat_messagewindow").is(":visible")){
				$('#fc_chat_messagewindow').append("<p class='fc_hold_msg'>"+FRESH_CHAT_SETTING.thank_message+"</p>");
			}
		},
		typing:function(){
			if(this.id==FRESH_CHAT_ID){return;}
			if(!this.triggerTypeTimer){
				if(!window.userName){
					window.userName = ($.cookie('fc_vname') && $.cookie('fc_vname')!="")?$.cookie('fc_vname'):userId;
				}
				chat_socket.emit('typing',{id:this.id,userId:userId,name:window.userName});
				var that = this;
				this.triggerTypeTimer = setTimeout(function(){
					that.triggerTypeTimer = null;
				},10000);
			}
		},
		onTyping:function(data){
			if(userId == data.userId){ return; }
			var that = this;
			
			this.typingStatus(data);
			this.typingTimer = setTimeout(function(){
				that.clearTyping(true);
		 	},10000);
		},
		clearTyping:function(timeout){
			if(this.typingTimer){
				if(!timeout){ clearTimeout(this.typingTimer); }
				this.typingTimer = null;
			}
			this.clearTypingStatus();
		},
		typingStatus:function(data){
			$("#fc_status").html(data.name+" "+FRESH_CHAT_SETTING.typing_message).show();
		},
		clearTypingStatus:function(){
			$("#fc_status").html("").hide();
		}
	});
  return new ChatView();
});