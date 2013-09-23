define([
      'models/user'
    ], 
    function(User){
          var Users = Backbone.Collection.extend({
              model: User,
              url: function () {
                return '/all_agents.json';
              },                            
              parse: function(resp, xhr) {
                var users = [];
                for(var u=0;u<resp.length;u++){
                      users[u] = resp[u].user;
                      users[u].username = users[u].name;
                      users[u].status = 0;
                }               
                return users;
              },
              onlineAgents:function(){                
                var count = this.where({status: 1 }).length;            
                return count;
              }
          });
          if(!window.users){
            window.users = new Users();
          }
          return window.users;
     });