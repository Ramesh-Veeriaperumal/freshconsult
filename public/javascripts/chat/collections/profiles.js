define([
      'models/profile'
    ], 
    function(Profile){
          var Profiles = Backbone.Collection.extend({
              model:Profile,
              url:'/users',              
          });       
    });