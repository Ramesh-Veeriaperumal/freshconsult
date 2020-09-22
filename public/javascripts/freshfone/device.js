(function ($) {
    "use strict";
	$(document).ready(function() {

	freshfoneuser.initializeDevice();
	// private methods
	function previewMode() { return (freshfonecalls.tConn.message || {}).preview; }
	function recordingMode() { return (freshfonecalls.tConn.message || {}).record; }
	if (typeof (Twilio) !== "undefined") {
		Twilio.Device.ready(function (device) {
			if(freshfonecalls.lastAction){
				freshfonecalls.lastAction();
			}
		});

		Twilio.Device.error(function (error) {
			freshfonecalls.error = error;
			freshfonecalls.errorcode = error.code;
			ffLogger.logIssue("Call Failure ", {"error": error}, 'error');
			if(freshfonecalls.errorcode == 31003){ //for ICE Liveness Check
				$(window).trigger('ffone.networkDown'); // for non-chromium based browsers
			}
			else if(freshfone.newNotifications && freshfonecalls.errorcode == 31002 && freshfonecalls.isCallActive()) {
				handleConnectionDeclined();
			}
			else{
				freshfoneNotification.resetJsonFix();
				notification().popAllNotification();

				freshfonecalls.resetRecordingState();
				freshfonewidget.resetPreviewButton();
				if(freshfoneSupervisorCall.isSupervisorOnCall){
					freshfoneSupervisorCall.resetJoinCallButton();
				}
				// if ($.inArray(error.code, [400, 401, 31204, 31205]) > -1) {
					// freshfoneuser.getCapabilityToken(undefined, true);
				// }
			}
		});

		Twilio.Device.offline(function (device) {
			if(freshfoneuser.tokenRegenerationOn == null)
				regenerateToken();
			else{
				if((freshfoneuser.tokenRegenerationOn - new Date()) > 3600000)
					regenerateToken();	
			}
				
		});

		Twilio.Device.connect(function (conn) {
			var twilioConnect = new TwilioConnect(conn, notification());
		});

		Twilio.Device.disconnect(function (conn) {
			if(freshfonecalls.canTrackQuality()){
				freshfonecalls.freshfone_monitor.stopLogging();
			}
			freshfoneNotification.resetJsonFix();
			freshfoneDialpadEvents.hideContactDetails();
			freshfonewidget.resetWidget();
			ffLogger.log({'action': "Call ended", 'params': conn.parameters});
			if (freshfonecalls.tConn) {
				var callSid = freshfonecalls.tConn.parameters.CallSid;
				var detail = callSid ? callSid : 'To :: '+ freshfonecalls.tConn.message.PhoneNumber;
				ffLogger.logIssue("Freshfone Call :: " + detail);
			}else{
				closeWidgetAndResetUser();
				return;
			}
			if (recordingMode()) {
				return freshfonecalls.fetchRecordedUrl();
			}
			if (freshfonetimer.timerElement.data('runningTime') < 5) {
				ffLogger.logIssue('Freshfone Short Call :: ' + detail, '', 'error');
			}
			freshfonetimer.stopCallTimer();
			freshfonecalls.enableCallButton();

			if (previewMode()) {
				freshfonewidget.resetPreviewMode();
				freshfonewidget.resetPreviewButton();
				return freshfonewidget.handleWidgets('outgoing');
			}

			freshfonecalls.tConn = conn;
			if (freshfonecalls.hasUnfinishedAction()) {
				return;
			} else if(freshfoneSupervisorCall.isSupervisorConnected)
			{
				freshfoneSupervisorCall.resetToDefaultState();
			} else if (!freshfonecalls.dontShowEndCallForm()) {
				var in_call_time = parseInt($(freshfonetimer.timerElement).data('runningTime') || 0, 10)
				if ( in_call_time < 3){ // less than 3 seconds is an invalid case.
					closeWidgetAndResetUser();
					return;
				}
				if(!freshfonecalls.transferSuccess && !freshfonecalls.callError()){//edge case where call disconnect comes first before transfer success.
					freshfoneendcall.showEndCallForm();
				}
				freshfonecalls.transferSuccess = false;
			} else {
				if(freshfone.isConferenceMode){
					if(freshfonecalls.isTransfering() && !freshfonecalls.transferSuccess){
						if (!freshfonecalls.callError())
							freshfoneendcall.showEndCallForm();
						freshfonecalls.freshfoneCallTransfer.resetTransferState();
						jQuery('.popupbox-tabs .transfer_call').trigger('click');
					}
					if(freshfonecalls.endCallFormForConference()) {
						freshfonewidget.handleWidgets();
					}
					freshfoneuser.resetStatusAfterCall();
					freshfoneuser.updatePresence();
				} else {
					freshfonewidget.resetTransferingState();
				}
				freshfonecalls.init();
				freshfoneuser.init();
			}
			freshfonecalls.lastAction = null;
			// freshfonewidget.hideTransfer();
			freshfonecalls.call = null;
			freshfonecalls.callInitiationTime = null;
		});

		Twilio.Device.cancel(function (conn) {
			// freshfonecalls.enableCallButton();
			freshfoneNotification.closeConnections(conn);
			var callSid = conn.parameters.CallSid ||  'To :: '+ freshfonecalls.tConn.message.PhoneNumber;
			ffLogger.log({'action': "Rejected/canceled the Call Notification", 'params': conn.parameters});
			ffLogger.logIssue("Freshfone Call :: " + callSid);
		});

		Twilio.Device.incoming(function (conn) {
			// freshfonecalls.disableCallButton();
			if(deviceWithActiveConnection()) {
				ffLogger.logIssue("New incoming call on busy device!", {'action': "Incoming Call Notification", 'params': conn.parameters}, 'error');
				
				conn.reject();
			} else {
				ffLogger.log({'action': "Incoming Call Notification", 'params': conn.parameters});
				freshfoneNotification.anyAvailableConnections(conn);
				if(!freshfone.newNotifications){
					var freshfoneConnection = new FreshfoneConnection(conn);
					freshfoneConnection.incomingAlert();
				}
			}
		});
	}

	function  notification(){
     return freshfone.newNotifications && !freshfonecalls.isAgentConference ? incomingNotification : freshfoneNotification;
  }

	function closeWidgetAndResetUser(){
		freshfonewidget.handleWidgets('outgoing');
		freshfoneuser.resetStatusAfterCall();
		freshfoneuser.updatePresence();					
	}
	function deviceWithActiveConnection() {
		var activeConnection = Twilio.Device.activeConnection();
		return (activeConnection && 
			activeConnection.status()=="open");
	}

	function regenerateToken () {
		freshfoneuser.getCapabilityToken();
		freshfoneuser.tokenRegenerationOn = new Date();
	}
	function handleConnectionDeclined(){
		var connnection = incomingNotification.currentConnection();
		if(connnection){
			freshfoneendcall.id = connnection.callId();
			freshfoneendcall.callSid = connnection.callSid();
			$('.end_call').trigger('click');
		}
		else{
			freshfonewidget.handleWidgets();
		}
	}
	});
	$(window).on("load", function(){
		Twilio.Connection.prototype.getMediaStream = function(){
			return this.mediaStream;
		}
	});

}(jQuery));
