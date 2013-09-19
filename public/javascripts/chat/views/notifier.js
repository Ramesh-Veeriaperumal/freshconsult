define([
  'text!templates/notifier.html'  
], function(notifierTemplate){
	var $ = jQuery;
	var scrollTitles=[];
	var NotifierView = Backbone.View.extend({
		notifiers:[],
		transferTimer:'',
		container:function(){
			var chatNotifierContainer = $("#chat_notifier_container");

			if(chatNotifierContainer instanceof $ && chatNotifierContainer.length!=0){
				return chatNotifierContainer;
			}

			chatNotifierContainer = $("<div id='chat_notifier_container' class='notifier-container'/>");
			$(document.body).append(chatNotifierContainer);
			
			return chatNotifierContainer;
		},
		visitor_alert:function(visitor){
			var that = this;
			var visitor_content = $('#content_'+visitor.userId);
			if(visitor_content.length>0){
				visitor.msg = visitor.msg.length < 140 ? visitor.msg : (visitor.msg).substring(0,140) + "...";
				visitor_content.append("<p>"+visitor.msg+"</p>");
			}else{
				var notifier = this.notifier('visitor_alert_'+visitor.userId,visitor,"visitor");							
				$('#but_'+visitor.userId).on('click',function(){
					chat_socket.emit('accept visitor',{userid:visitor.userId, name:visitor.name});
			 		localStore.remove('visitor',visitor.userId);
					that.remove(notifier);
				});
				$('#ignore_'+visitor.userId).on('click',function(){
			 		localStore.remove('visitor',visitor.userId);
					that.remove(notifier);
				});
				soundManager.play('new_visitor');
			}
		},
		transfer:function(data){
			var that = this;
			data.name = userCollection.get(data.userId).get('name');
			var notifier = this.notifier('transfer_'+data.id,data,"transfer");
			$('#but_'+data.id).on('click',function(){
				chat_socket.emit('accept transfer',data);
		 		localStore.remove('transfer',data.chatId);
				that.remove(notifier);
				clearTimeout(that.transferTimer);
			});
			$('#ignore_'+data.id).on('click',function(){
				chat_socket.emit('transfer ignored', data);
		 		localStore.remove('transfer',data.chatId);
				that.remove(notifier);
				clearTimeout(that.transferTimer);
			});
			this.transferTimer = setTimeout(function(){
				chat_socket.emit('transfer ignored', data);
		 		localStore.remove('transfer',data.chatId);
				that.remove(notifier);
				clearTimeout(that.transferTimer);
			},120000);
			soundManager.play('transfer');
		},
		notifier:function(notifierId,data,type){
			if(data.city=='' && data.country==''){
				data.location="Unknown";
			}else{
				data.location=data.city+","+data.country;
			}
			var data = (type=="visitor")?{visitor:data,id:data.userId}:{transfer:data,id:data.id};				
			var notifier = $('<div>');
			notifier.attr('id',notifierId);
			notifier.addClass('notifier');
			this.container().append(notifier.html(_.template(notifierTemplate,{"data":data})));
			this.notifiers.push(notifier);
			return notifier;
		},
		remove:function(notifier){			
			if(notifier){notifier.remove();}
			for(var n=0; n<this.notifiers.length;n++){
				if(this.notifiers[n].attr("id") == notifier.attr("id")){
					 this.notifiers.splice(n,1);
				}
			}
			if(this.notifiers.length==0){
				this.container().remove();
			}
		},
		ignore:function(data){
			var id = data.id;
			localStore.remove('visitor',data.id);
			if($("#visitor_alert_"+id).length>0){
				this.remove($("#visitor_alert_"+id));
			}
			if($("#transfer_"+id).length>0){
				this.remove($("#transfer_"+id));
			}
		},
		scroll:function(msg){
			if(!window.active){
				if(scrollTitles.length==0) {scrollTitles.push(document.title);}
				if($.inArray(msg.name, scrollTitles) == -1) {scrollTitles.push(msg.name);}
				if(scrollTitles.length==2){this.startScroll(scrollTitles);}
			}
		},
		startScroll:function(titles){
			var i = 0;
			function stop(titles) {
			   document.title = titles[0];
			   clearInterval(focusTimer);
			   scrollTitles = [];
			}
			
			function change(titles) {
				var index = i++ % titles.length;
		      	document.title = index==0 ? titles[index] : titles[index]+" "+i18n.says+"...";
				if(window.active){
					stop(titles);
				}
			}
			var focusTimer = setInterval(function() { change(titles); }, 2000);
		},
		
		reOpen:function(){
			var that = this;
			var type = ['chat','visitor','transfer'];
	     	for(var i=0; i<type.length; i++){
	     		var notifiers = localStore.get(type[i]);
	     		if(notifiers){
	     		 	var obj = notifiers.split('#');
		            for(var j=0; j< obj.length; j++){
		            	var notifier = localStore.IsJson(obj[j]) ? JSON.parse(obj[j]) : obj[j];
		            	var timeNow = (new Date()).getTime();
	            	 	if(type[i]=='chat'){
	            	 		var chatId = notifier;
            	 		  if($("#tabs-chat-"+chatId).length == 0){
							    chat_socket.emit('join chat',{
					          		 id: chatId
					        	});	
							}
							else{
					        	chat_socket.emit("transcript request",{
										id: chatId,
										reconnect: 1
					        	});
					        }
				        }
				        if(timeNow < (notifier.createdTime+120000)){        // reopen notifications if it came before 2 minutes
			               	if(type[i]=='transfer'){
					         	 that.transfer(notifier);
				         	}
					        else if(type[i]=='visitor'){
						         that.visitor_alert(notifier);
						    }
				        }
				        else{
				        	localStore.remove('visitor',notifier.id);
				        }
		            }
	     		}
	    	}
		}
	});
	return (new NotifierView());
});