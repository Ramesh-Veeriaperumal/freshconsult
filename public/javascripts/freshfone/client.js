var globalconn;
(function ($) {
	"use strict";

// optimize
	$(document).ready(function () {
		var $widget = $('.freshfone_widget'),
			$contentContainer = $('.freshfone_content_container'),
			$recentCalls = $contentContainer.find('#recent_calls'),
			$recentCallsContainer = $recentCalls.find('.recent_calls_container');

		$widget.popupbox();

		// Freshfone button bindings with actions
		$('#mute').click(function () { freshfonecalls.mute(); });
		$("#hold").click(function(){freshfonecalls.handleHold();});
		$('#hangup_call').click(function () { freshfonecalls.hangup(); });
		$("#freshfone-presence-toggle").click(function () { freshfoneuser.toggleUserPresence(); });
		$widget.find('.availabilityOnPhone').click(function () {
			if (!freshfone.isTrial){
				freshfoneuser.toggleAvailabilityOnPhone(false);
			}
		});
		
		// Recent Calls show
		$widget.find('[href="#freshfone_dialpad"]').on('shown', function (e) {
			if (freshfone.isTrial && freshfoneSubscription.showDialpadWarnings()){
				return;
			}
			freshfoneDialpadEvents.showDialpadElem();
			$recentCalls.addClass('loading-small sloading');
			$recentCallsContainer.hide();
			$.ajax({
				url : freshfone.recent_calls_path,
				success : function () {
				},
				error: function () {
					$recentCalls.removeClass('loading-small sloading');
					$recentCallsContainer.show();
				}
			});
		});

		//Load Transfer agents
		$widget.find('[href="#freshfone_available_agents"],[href="#freshfone_agents_list"]').on('shown', function (e) {
			$("#freshfone_available_agents").find('.available_agents_list')
			                                .toggleClass("adding_agent_state",freshfonecalls.isAgentConferenceActive);
			freshfonesocket.loadAvailableAgents();
		});



		freshfonewidget.showOutgoing();

		if (freshfone.below_threshold) {
			freshfonewidget.disableFreshfoneWidget();
		}


		$('body').on('click', '.can-make-calls', function (ev) {
			ev.preventDefault();
			if(!$(this).find('div').hasClass('phone-icons')){
			if ($(this).data('phoneNumber') !== undefined) {
				freshfonecalls.recentCaller = 1;
				freshfonecalls.number = $(this).data('phoneNumber');
				freshfoneContactSearch.getSearchResults(
					freshfonecalls.number, $(this).data('contactId'),
					$(this).data('deleted'));
				$('#number').intlTelInput("setNumber", freshfonecalls.number)
										.trigger('input');
				freshfonecalls.selectFreshfoneNumber($(this).data('freshfoneNumberId'));
				setTimeout(function () { 
					freshfonewidget.showDialPad(); 
					$("#search_bar").show();	
					}, 1); 
			}
		}	
				
		});

	
	
	});
		
		

}(jQuery));
