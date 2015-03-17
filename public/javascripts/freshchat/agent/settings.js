(function($){
	'use strict';
	window.liveChat = window.liveChat || {};
	
 	$(document).on('agent-availability:success', function(event, agentData){
	 	if(!$('#chat-availability').length){
	 		
	 		//Load livechat availability template
	 		var availabilityTemplate = window.JST['freshchat/templates/availability'];
	 		console.log("availabilityTemplate:::",availabilityTemplate);
			$("#wrap .wrapper .header-link-wrapper").prepend(availabilityTemplate({availableStatus: agentData.status}));

			// chat-available icon click handler
			$('#chat-availability').on('click',function(){
		 		var active;
		 		
		 		if($("#chat-availability img").hasClass("agent-fchat-on")){
					active = false;
				}else if($("#chat-availability img").hasClass("agent-fchat-off")){
					active = true;
				}

				//toggle the chat icon symbol in availability 
				$("#chat-availability img")
				.removeClass("agent-fchat-on agent-fchat-off")
				.addClass("header-spinner");

				window.liveChat.updateAvailability(active);
			});
		}

		var sound = [];
		_.each(agentData.availablePingTones, function(value, key){
			sound.push({ id: key, text: value.split('.')[0] });
		})
		
		$('#change_ping_tone').select2({ 
				data: sound,
        minimumResultsForSearch: Infinity,
				initSelection: function(element, callback) {
					var selectedElement = _.find(sound, function(obj){ return obj.id == element.val() });
          callback(selectedElement);
        }
		 }).select2('val', agentData.ping_tone);

		$("#change_ping_tone").on('change', function(element){
			window.liveChat.updatePingTone(element);
		});

  });

  $(document).on('agent-availability:change', function(event, status){
  	window.freshchat_status = status;
		$("#chat-availability").attr('data-original-title', status ? CHAT_I18n.click_to_go_offline : CHAT_I18n.click_to_go_online)
			.find('img')
			.removeClass("agent-fchat-on agent-fchat-off header-spinner")
			.addClass("agent-fchat-"+ (status ? "on" : "off"))
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

})(jQuery);