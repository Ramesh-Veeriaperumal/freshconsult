define([
      'models/chat'
    ], 
    function(Chat){
          var Chats = Backbone.Collection.extend({
              model: Chat,
              url:"javascript:void();",
              parse: function(resp, xhr) {                
                return resp;
              },
              addNew:function(chat){              	
              	chat = this.create(chat)
					this.add(chat);
					return chat;
              },
              updateTranscript:function(data){
	            	this.findAndExec(data.id,data,function(chat,data){
	            			if(chat){chat.updateTranscript(data);}
	            	});
              },
              updateMessage:function(data){
              		this.findAndExec(data.chatId,data,function(chat,data){
            			if(chat){chat.update(data);}
            		});
              },
              findAndExec:function(id,data,fn){                  
                  for(var m=0;m<this.models.length;m++){
         		      var chat =  this.models[m];          
                    	if(chat.id == id){                              
                    		fn(chat,data);                              
                              return;
                    	}
                  }

                  chat_socket.emit('join chat',{
                    id: id
                  });
              },
              findByUser:function(id){
                var chatId = "";
                var chats = this.filter(function(chat){return (chat.userId==id && chat.ptype=='agent');});
                for(var m=0;m<chats.length;m++){
                  chatId = chats[m].id;
                }
                return chatId;
              }
          });
          return Chats;
     });