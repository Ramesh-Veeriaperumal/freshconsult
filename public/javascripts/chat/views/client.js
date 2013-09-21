define([
    'views/users',
    'views/chat',
    'views/page',
    'views/notifier',
    'views/recent_chats',    
    'views/flash',
    'collections/users',
    'views/search/results',
    'views/search/listing',
    'views/dashboard',
    'views/visitor_list',
    'views/chat/ticket_options',
    'text!templates/search/message.html'
    ], 
function(UserView,ChatView,PageView,notifierView,recentView,flashView,userCollection,resultsView,listView,dashboardView,visitorView,ticketView,messageTemplate){
    var $ = jQuery;
    var connectionObject;
    var Client = Backbone.View.extend({
      namespace:"/freshdesk",
      initialize:function(){
        var query = 'i='+CURRENT_USER.id+'&s='+$.cookie('helpdesk_node_session')+'&sid='+SITE_ID+'&c=fd';
        var session = {};
        session.user_id = CURRENT_USER.id;
        session.site_id = SITE_ID;
        session.site_code = 'fd';
        var sessionStr = JSON.stringify(session);
        var encodedSession = Base64.encode(sessionStr);
        $.cookie("CA", encodedSession, { expires: 1, path: '/'});
        var chat_socket = io.connect(CS_URL+'?'+query);
        window.chat_socket = chat_socket.of(this.namespace);
      }, 
      show:function(){      
        $('#container').show().delay(1000);
        $('#splash').hide();
        this.listen();
      },      
      isAuthorized:function(data){
        var sessionStr =  $.cookie('CA');
        var decodedSession = Base64.decode(sessionStr);
        var session = JSON.parse(decodedSession);
            return  (($.cookie('helpdesk_node_session') != data.session) ||
                     (session.user_id !=  data.id) || 
                     (session.site_code != data.code) || 
                     (session.site_id != data.site_id))
      },
      logout:function(){
        window.location = '/logout';
      },
      flash:function(cls,text,timeout){
          flashView.removeFlash(connectionObject);
          connectionObject = flashView.render({'classname':cls,'txt':text});
          if(timeout){setTimeout(function(){flashView.removeFlash(connectionObject);}, timeout);}
      },
      listen:function(){
          var self = this;
          (function() {
            var emit = chat_socket.emit;
            chat_socket.emit = function() {
              var emitArg = Array.prototype.slice.call(arguments);
              if(CHAT_DEBUG==4){
                console.log('***','emit', emitArg);
              }
              if(emitArg[0]=="accept visitor" || emitArg[0]=="join chat" || emitArg[0]=="create chat"){
                if(emitArg[0]=="join chat"){
                  self.flash('chat_info', i18n.join_chat);
                }else{
                  self.flash('chat_info', i18n.info_msg);
                }
              }
              emit.apply(chat_socket, arguments);
            };
            var $emit = chat_socket.$emit;
            chat_socket.$emit = function() {
              var onArg = Array.prototype.slice.call(arguments);
              if(CHAT_DEBUG==4){
                console.log('***','on', onArg);
              }
              if(onArg[0]=="chat created" || onArg[0]=="joined chat" || onArg[0]=="visitor picked"){
                flashView.removeFlash(connectionObject);
              }
              $emit.apply(chat_socket, arguments);
            };
          })();

          chat_socket.on('error', function (reason){
            self.flash('chat_error',i18n.connection_error_msg);
          });

          chat_socket.on('disconnect', function (reason){
            self.flash('chat_error',i18n.connection_error_msg);
          });

          chat_socket.on('connect', function (){
            flashView.removeFlash(connectionObject);
            chat_socket.emit("join",{
              room_id: SITE_ID
            });            
            chat_socket.emit('get status',USER_LIST);
          });

          chat_socket.on('auth check',function (data){
            if(self.isAuthorized(data)){
                self.flash('chat_error',i18n.unauthorized_attempt_msg,10000);
                self.logout();
            }
          }); 

          chat_socket.on('new visitor',function(visitor){
            visitor.id = visitor.userId;
            visitor.createdTime = (new Date()).getTime();
            localStore.store('visitor',visitor);
            notifierView.visitor_alert(visitor);
          });

          chat_socket.on('new msg',function(msg){
            ChatView.update(msg);
          });

          chat_socket.on('chat created', function(chat){             
             ChatView.render(chat);
             if(chat.participant && chat.ptype == "agent"){
               userCollection.get(chat.participant.userId).map(chat);
             }
          });

          chat_socket.on('joined chat', function(chat){ 
            if(CURRENT_USER.id != chat.userId){
              if($('#tabs-group').find('li').hasClass('ui-state-active'))
              {
                var id = $('li.ui-state-active').find('a').attr('href');
                var data = {prev_chat:1, prev_chatid:id};
              }     
            }      
            ChatView.render(chat,data);
          });

          chat_socket.on('transcript response', function(transcript){            
            ChatView.updateTranscript(transcript);
          });

          chat_socket.on('recent response', function(chats){                        
            recentView.update(chats);
          });

          chat_socket.on('search response',function(msgs){
            resultsView.render(msgs);
          });

          chat_socket.on('chat transcript',function(msgs){
            listView.render(msgs);
          });          

          chat_socket.on('visitor accepted', function(data){
            visitorView.changeVisitor(data);
            notifierView.ignore(data);
          });

          chat_socket.on('visitor connect', function(data){
            visitorView.newVisitor(data);
          });

          chat_socket.on('visitor disconnect', function(data){
            visitorView.removeVisitor(data);
            ChatView.status(data);
            notifierView.ignore(data);
          });

          chat_socket.on('new member', function(data){             
             
          });

          chat_socket.on('typing', function(data){             
            var chat = chatCollection.get(data.id);            
             if(chat){chat.onTyping(data);}
          });
          
          chat_socket.on('get status',function(data){             
            ChatView.agentStatus(data);
            notifierView.reOpen();
            visitorView.fetch();
          });

          chat_socket.on('status',function(data){             
            ChatView.agentStatus(data);
          });

          chat_socket.on('transfer request',function(data){
            data.id = data.chatId;
            data.createdTime = (new Date()).getTime();
            localStore.store('transfer',data);
            notifierView.transfer(data);
          });

          chat_socket.on('transfer accepted',function(data){
            visitorView.accept(data);
            ChatView.transfer(data);
          });

          chat_socket.on('transfer ignored',function(data){
            ChatView.ignored(data);
          });

          chat_socket.on('create ticket',function(chat){
            if(chat.messages.length > 0){
              ticketView.render(chat);
            }
            else{
              ChatView.closeWindow(chat);
            }
          });

          chat_socket.on('reconnect',function(){
              chat_socket.emit('reconnect');
              chat_socket.emit('get status',USER_LIST);
          });

          $(window).unload(function(){
                $.cookie("CA", null);
                chat_socket.disconnect();
          });
          PageView.init();
      }      
    });

    return new Client;

});