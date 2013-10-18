// Filename: router.js
define([
  'view/users/list'
], function(UserListView){
  var AppRouter = Backbone.Router.extend({
    routes: {
      // Define some URL routes      
      '/users': 'showUsers',

      // Default
      '*actions': 'defaultAction'
    }
  });

  var initialize = function(){
    var app_router = new AppRouter;    
    // As above, call render on our loaded module
    // 'views/users/list'
    app_router.on('showUsers', function(){
      var userListView = new UserListView();
      userListView.render();
    });
    app_router.on('defaultAction', function(actions){
      // We have no matching route, lets just log what the URL was
      console.log('No route:', actions);
    });
    Backbone.history.start();
  };
  return {
    initialize: initialize
  };
});