define([
    'text!templates/online_users.html'
], function(UserListTemplate){
    var $ = jQuery;
    var OnlineUsersWidget = Backbone.View.extend({        
        render: function () {
          _.each(userCollection.models, function(user) {
            if(CURRENT_USER.id != user.get('id') && !user.get('deleted')){
              $('#user_list').append(_.template(UserListTemplate, {user: user, $:$}));
              $("#user-"+user.get('id')).on('click',function(){
                user.chat();
              });
            }            
          });

          if(userCollection.models.length==1){
              $('#user_list').append(_.template("<div class='chat_add_agent'>"+i18n.add_agent_to_chat+"</div>"));
          }
          $('#user_menu').addClass('open');
          chat_socket.emit('get status',USER_LIST);
        }
    });
    return new OnlineUsersWidget();
});