define([], 
	function(){
	var $ = jQuery;	
	var ChatModel = Backbone.Model.extend({				
		constructor: function(chat) {			
		    $.extend(this,chat);
	  	},
		send:function(msg){			   
			if(this.command(this.id,msg)){return;}
			chat_socket.emit("my msg",{
				id: this.id,
				msg: msg,
				username:CURRENT_USER.username,
				photo: "/users/"+CURRENT_USER.id+"/profile_image"
			});
		},
		command:function(chatid,msg){			
			if(msg=="\\history"){				
				this.transcript(this.id);
				return true;
			}
			return false;
		},
		transcript:function(){
			var chats = [];
			if(this.visitor && this.visitor.chats){
				chats = chats.concat(this.visitor.chats);
			}
			chats.push(this.id)
			chat_socket.emit("transcript request",{
					id: this.id,
					chats: chats
			});
		},
		update:function(msg,chatid){
			if(!chatid){
					chatid = msg.chatId;
			}
			if(CURRENT_USER.id!=msg.userId){
				this.clearTyping();
			}
			var inner = $('#chat-messages-inner-'+chatid);			
			if(inner.length>0){				
				inner.append(this.parseMessage(msg));
				var container = $('#chat-messages-'+chatid);
				container.scrollTop(inner.height());
				return;
			}
		},
		changeTitle:function(title){
			this.view.tab.title(this.id,title);
		},
		updateTranscript:function(data){
			var oldMessages = $('#chat-messages-inner-'+data.id).find('p');
        	if(oldMessages.length){
				oldMessages.remove();
			}
			var history = data.history;
			for(var h=0;h<history.length;h++){
					this.update(history[h],data.id);
			}
		},
		parseMessage:function(msg){
			var time = new Date(msg.createdAt);
			var today = new Date();
			if(today.setHours(0,0,0,0) == time.setHours(0,0,0,0)){
				time = new Date(msg.createdAt);
				var hours = time.getHours();
				var minutes = time.getMinutes();
				if(hours < 10) hours = '0' + hours;
				if(minutes < 10) minutes = '0' + minutes;
				msg.time = hours +":"+ minutes;
			}else{
				msg.time = time.getDate()+" "+this.getMonthName(time.getMonth());
			}
			msg.msg = this.parseURL(msg.msg);
			if(CURRENT_USER.id == msg.userId){
				msg.class = 'self';
			}else{
				msg.class = 'guest';
				if(!userCollection.get(msg.userId)){
					var details = this.parseDetails(msg.msg);
					msg.msg = details.msg;
					if(details.class){
						msg.detclass = details.class;
						if(details.mail){
							msg.mail = details.mail;
						}
						if(details.phone){
							msg.phone = details.phone;
						}
					}
				}
			}
			var html = _.template(this.view.messageTemplate,{msg:msg});
			return html;
		},
		getMonthName:function(mon){
			var monthNames = [ "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec" ];
			return monthNames[mon];
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
		parseDetails:function(msg){
			var detail={}, mail="", phone="", i=0, len=0;
			var phoneRegExp  = /(([+\s]\d+)*\d+){6,}/gi;
			var mailRegExp  = /([a-z0-9]([a-z0-9_\-\.]*)@([a-z0-9_\-\.]*)(\.[a-z]{2,3}(\.[a-z]{2}){0,2}))/gi;
			var mat = msg.match(phoneRegExp);
			if(mat){
				len = mat.length;
				detail.class = 'visitor_info_link';
				detail.phone = mat;
				for(i=0;i<len;i++){
					msg = msg.replace(mat[i], _.template(this.view.infoTemplate,{type:'phone', icon:'mobile', data:mat[i]}));
				}
			}
			mat = msg.match(mailRegExp);
			if(mat){
				len = mat.length;
				detail.class = 'visitor_info_link';
				detail.mail = mat;
				for(i=0;i<len;i++){
					msg = msg.replace(mat[i], _.template(this.view.infoTemplate,{type:'mail', icon:'mail', data:mat[i]}));
				}
			}
			detail.msg = msg;
			return detail;
		},
		typing:function(){			
			if(!this.triggerTypeTimer){
				chat_socket.emit('typing',{id:this.id,userId:CURRENT_USER.id,name:CURRENT_USER.username});
				var that = this;
				this.triggerTypeTimer = setTimeout(function(){
					that.triggerTypeTimer = null;
				},10000);
			}
		},
		onTyping:function(data){
			if(CURRENT_USER.id == data.userId){ return; }			
			var that = this;
			if(this.view){
				this.view.typingStatus(this,data);
				this.typingTimer = setTimeout(function(){				
					that.clearTyping(true);
			 	},10000);
			}
		},
		clearTyping:function(timeout){
			if(this.typingTimer){
				if(!timeout){ clearTimeout(this.typingTimer); }
				this.typingTimer = null;
			}			
			if(this.view){ this.view.clearTypingStatus(this); }
		}
	});
	
	return ChatModel;

});