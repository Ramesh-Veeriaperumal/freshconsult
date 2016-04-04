(function($){
  'use strict';
    $(document).on('agent-availability:success', function(event, agentData){
      var sound = [];
      _.each(agentData.availablePingTones, function(value, key){
        sound.push({ id: key, text: value.split('.')[0] });
      });
      
      $('#change_ping_tone').select2({ 
          data: sound,
          minimumResultsForSearch: Infinity,
          initSelection: function(element, callback) {
            var selectedElement = _.find(sound, function(obj){ return obj.id == element.val() });
            callback(selectedElement);
          }
       }).select2('val', agentData.ping_tone);

      $("#change_ping_tone").on('change', function(element){
        freshChatSound.play('playTone', window.ASSET_URL.cloudfront+'/sound/'+agentData.availablePingTones[element.val]);
        window.liveChat.updatePingTone(element);
      });

      // when the tone is changed in one tab/browser it send a pusher event which inturn will trigger this updateToneName
      //event for updating in other tabs/browsers
      $(document).on('updateToneName', function(event, ping_tone){
        $('#change_ping_tone').select2('val', ping_tone);
      });

      //The livechat ping tone change DOM element is hidden and is only shown when the 
      // chat is connected(chat-connect event is fired).  
      $(document).on('chat-connect',function(event, data){
        $('.tone-customize').removeClass('hide').addClass('show');
      });
    });
})(jQuery);
