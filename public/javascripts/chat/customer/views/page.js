//Filename: page.js

define([  	
   'customer/views/chat'
], function(chatView){
  var init = function(){
        // layoutView.render();        
        chatView.render();  			
  }
  return {init:init};
});