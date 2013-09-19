define([
    'backbone',
    'underscore',
    'cookies'
    ], 

function(Backbone, _,Cookies){    
    var Client = Backbone.View.extend({
      namespace:"/visitor",
      initialize:function(){
        if($.cookie('fc_vid')!=null){
            userId = $.cookie('fc_vid');
        }        
        var query = 'i='+userId+'&sid='+FRESH_CHAT_ID+'&s='+FRESH_CHAT_SESSION+'&c=fd';
        var visitCount = 0;
        if($.cookie('fc_vcount')!=null){
            visitCount = $.cookie('fc_vcount');
            query = query+'&r='+visitCount;
        }
        var socket = io.connect(window.NODE_URL+'?'+query);
        window.chat_socket = socket.of(this.namespace);
      }, 
      show:function(chatView){
        this.chatView=chatView;
        this.listen();
      },
      listen:function(){
        
          (function() {
            var emit = chat_socket.emit;
            chat_socket.emit = function() {
              if(CHAT_DEBUG==4){
                console.log('***','emit', Array.prototype.slice.call(arguments));
              }
              emit.apply(chat_socket, arguments);
            };
            var $emit = chat_socket.$emit;
            chat_socket.$emit = function() {
              if(CHAT_DEBUG==4){
                console.log('***','on',Array.prototype.slice.call(arguments));
              }
              $emit.apply(chat_socket, arguments);
            };
          })();

          var that = this;
          chat_socket.on('error', function (reason){
            console.error('Unable to connect Socket.IO', reason);
          });

          chat_socket.on('connect', function (){
             console.info('successfully established a working connection');
          

              chat_socket.on('visitor info',function(data){
                window.userId = data.userId;
              });

              chat_socket.on('new msg',function(data){
                that.chatView.update(data);
              });

              chat_socket.on('visitor name',function(data){
                that.chatView.updateName(data);
              });

              chat_socket.on('blocked visitor',function(){
                that.chatView.blockVisitor();
              });

              chat_socket.on('unblocked visitor',function(data){
                that.chatView.unblockVisitor(data);
              });

              chat_socket.on('ping accepted', function(data){
                 that.chatView.id=data.id;
                 that.chatView.type="user";
                 that.chatView.waitMsg();
                 chat_socket.emit('join',{room_id:data.id});
                 $.cookie('fc_vid',userId);
                 var visitCount = 0;
                 if($.cookie('fc_vcount')!=null){
                    visitCount = parseInt($.cookie('fc_vcount'));
                 }
                 visitCount++;
                 $.cookie('fc_vcount',visitCount);
              });

              chat_socket.on('transfer',function(data){
                 chat_socket.emit('leave',{room_id:that.chatView.id});
                 that.chatView.id=data.id;
                 that.chatView.type="user";
                 that.chatView.waitMsg();
                 chat_socket.emit('join',{room_id:data.id,transfer:1});
              });

              chat_socket.on('status',function(data){
                var status = "offline";
                if(data.status==1){status="online";}
                var statusObj = $("#"+data.userid+"_status");
                statusObj.removeClass(statusObj.className);
                statusObj.addClass("status "+status);
              });

              chat_socket.on('team status', function(data){
                 if(data.online){
                      $("#fc_chat_layout").show();
                 }
              });

              chat_socket.on('chat close', function(data){
                that.chatView.closeChat(data);
              });

              chat_socket.on('typing', function(data){             
                 that.chatView.onTyping(data);
              });

              var findCity = function(obj){
                var status = false;
                if(obj && typeof obj === "string" && obj=="locality"){                    
                    status = true;
                }
                if(obj && obj instanceof Array){                                        
                    for(var o=0;o<obj.length;o++){
                        if(findCity(obj[o])){ 
                            status = true;
                            break;                
                        }
                    }
                }
                else if(obj && obj instanceof Object){
                    for (key in obj) {
                        if(findCity(obj[key])){                            
                            if(window.session.location.address.city.length==0){
                              window.session.location.address.city = obj.long_name;
                            }
                            status = true;
                            break;
                        }
                    }
                }
                return status;
              }

              var userName = $.cookie('fc_vname');
              var visitorDetail = window.session;
              if(userName != null){
                visitorDetail.name = userName;
              }
              chat_socket.emit('geo',visitorDetail);
              
              if(window.session.location && window.session.location.address && window.session.location.address.city.length==0){
                $.getJSON("http://maps.googleapis.com/maps/api/geocode/json?latlng="+window.session.location.latitude+","+window.session.location.longitude+"&sensor=true",function(data){
                    if(data && data instanceof Object){findCity(JSON.parse(JSON.stringify(data)));}
                    var visitorDetail = window.session;
                    if(userName != null){
                      visitorDetail.name = userName;
                    }
                    chat_socket.emit('geo',visitorDetail);
                 });
              }

              $(window).unload(function(){
                    chat_socket.disconnect();
              });
         }); 
      }
    });

    return new Client;

});