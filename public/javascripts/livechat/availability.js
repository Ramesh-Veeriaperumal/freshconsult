window.liveChat = window.liveChat || {};

(function($){
  'use strict';
  
  $(document).on('agent-availability:success', function(event, agentData){
    if(!$('#chat-availability').length){
      
      //Load livechat availability template
      var availabilityTemplate = window.JST['livechat/templates/availability'];
      $("#wrap .wrapper .header-link-wrapper").prepend(availabilityTemplate({availableStatus: agentData.status}));

      // chat-available icon click handler
      $('#chat-availability').on('click',function(){
        var active;
        
        if($("#chat-availability i").hasClass("ficon-agent-fchat-on")){
          active = false;
        }else if($("#chat-availability i").hasClass("ficon-agent-fchat-off")){
          active = true;
        }

        //toggle the chat icon symbol in availability 
        $("#chat-availability i")
        .removeClass("ficon-agent-fchat-on ficon-agent-fchat-off")
        .addClass("header-spinner");

        window.liveChat.updateAvailability(active);
      });
    }
  });

  $(document).on('agent-availability:change', function(event, status){
    window.liveChat.agentAvailabilityStatus = status;
    $("#chat-availability").attr('data-original-title', status ? CHAT_I18n.click_to_go_offline : CHAT_I18n.click_to_go_online)
      .find('i').removeClass("ficon-agent-fchat-on ficon-agent-fchat-off header-spinner").addClass("ficon-agent-fchat-"+ (status ? "on" : "off"))
  });

})(jQuery);
