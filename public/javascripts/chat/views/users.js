define([
    'text!templates/online_users.html'
], function(UserListTemplate){
    var $ = jQuery;
    var OnlineUsersWidget = Backbone.View.extend({        
        render: function () {
          userCollection.sort();
          _.each(userCollection.models, function(user) {            
            if(CURRENT_USER.id != user.get('id') && !user.get('deleted')){
              $('#user_list').append(_.template(UserListTemplate, {user: user, $:$}));
              $("#user-"+user.get('id')).on('click',function(){
                user.chat();
              });
            }            
          });

          if(userCollection.models.length==1){
              this.emptyMessage();
          }
          $('#user_menu').addClass('open');
          chat_socket.emit('get status',USER_LIST);
        },
        emptyMessage:function(){
          $('div.chat_add_agent').remove();
          $('#user_list').append(_.template("<div class='chat_add_agent'>"+i18n.add_agent_to_chat+"</div>"));
        },
        empty:function(){
          if(userCollection.onlineAgents() == 0){
                  this.emptyMessage();
          }
          else{
              $('div.chat_add_agent').remove();
          }
       },
      hideOffline:function(){     
        var users = userCollection.offlineAgents();             
        users.each(function(user){
          jQuery('#user-'+user.get('id')).css("display","none");
        });           
        this.empty();
      },
      updateStatus:function(data){          
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
              if(data.status==1){
                $('#user-'+user.get('id')).css("display","block");              
              }
              else{
                $('#user-'+user.get('id')).css("display","none");
              }
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
        if(data.reset){         
          that.hideOffline();
        }     
        else{
          that.empty();
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
    }
    });
    return new OnlineUsersWidget();
});