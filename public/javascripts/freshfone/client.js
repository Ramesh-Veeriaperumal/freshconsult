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
		$('#hangup_call').click(function () { freshfonecalls.hangup(); });
		$("#freshfone-presence-toggle").click(function () { freshfoneuser.toggleUserPresence(); });
		$widget.find('.availabilityOnPhone').click(function () {
			freshfoneuser.toggleAvailabilityOnPhone(false);
		});
		
		// Recent Calls show
		$widget.find('[href="#recent_calls"]').on('shown', function (e) {
			$recentCalls.addClass('loading-small sloading');
			$recentCallsContainer.hide();
			$.ajax({
				url : freshfone.recent_calls_path,
				error: function () {
					$recentCalls.removeClass('loading-small sloading');
					$recentCallsContainer.show();
				}
			});
		});

		//Load Transfer agents
		$widget.find('[href="#freshfone_available_agents"],[href="#freshfone_agents_list"]').on('shown', function (e) {
			freshfonesocket.loadAvailableAgents();
		});



		freshfonewidget.showOutgoing();

		if (freshfone.below_threshold) {
			freshfonewidget.disableFreshfoneWidget();
		}


		$('body').on('click', '.can-make-calls', function (ev) {
			ev.preventDefault();
			if(!$(this).hasClass('phone-icons')){
			if ($(this).data('phoneNumber') !== undefined) {
				freshfonecalls.recentCaller = 1;
				freshfonecalls.number = $(this).data('phoneNumber');
				$('#number').intlTelInput("setNumber", freshfonecalls.number);
				freshfonecalls.selectFreshfoneNumber($(this).data('freshfoneNumberId'));
				setTimeout(function () { freshfonewidget.showDialPad(); }, 1); 
			}
		}	
				recordSource($(this).parent().prop('className'));
		});

		function recordSource(parentClass){
			switch(parentClass){
				case "recent_calls_container":
					App.Phone.Metrics.recordSource("RECENT_CALL_BTN");
					break;
				case "call_user pull-right":
					App.Phone.Metrics.recordSource("CLICK_CALL_BTN");
					break;
				case "recent_calls_call_user","recent calls":
					break;
				default:
					App.Phone.Metrics.recordSource("CLICK_NUM");
					break;
			}
		}
	});
		
		

}(jQuery));
