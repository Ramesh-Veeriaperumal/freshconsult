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
			if(freshfonecalls.errorcode == 31003){ //for ICE Liveness Check
				$(window).trigger('ffone.networkDown'); // for non-chromium based browsers
			}
			else{
				ffLogger.logIssue("Call Failure ", {"error": error}, 'error');
				freshfoneNotification.resetJsonFix();
				freshfoneNotification.popAllNotification();
				freshfonecalls.resetRecordingState();
				freshfonewidget.resetPreviewButton();
				// if ($.inArray(error.code, [400, 401, 31204, 31205]) > -1) {
					// freshfoneuser.getCapabilityToken(undefined, true);
				// }
			}
		});

		Twilio.Device.offline(function (device) {
			console.log("Device offline");
			freshfoneuser.getCapabilityToken(undefined, true);
		})

		Twilio.Device.connect(function (conn) {
			freshfonecalls.tConn = conn;
			ffLogger.log({'action': "Call accepted", 'params': conn.parameters});
			if(!freshfonecalls.isOutgoing() && !freshfonecalls.conferenceMode) { freshfoneNotification.initializeCall(conn); }
			freshfonecalls.resetFlags();
			if (recordingMode()) { return freshfonecalls.setRecordingState(); }
			freshfoneNotification.resetJsonFix();
			if(freshfonecalls.isOutgoing()){
		    	$('#number').intlTelInput("updatePreferredCountries");
		    	freshfonecalls.registerCall(conn.parameters.CallSid);
	     } 
			var accecptedConnection = freshfonecalls.conferenceMode ? freshfonecalls.conferenceConn : conn
			freshfoneNotification.popAllNotification(accecptedConnection);
			freshfonetimer.startCallTimer();
			freshfonewidget.toggleWidgetInactive(false);
			freshfonewidget.hideTransfer();
			freshfonewidget.handleWidgets('ongoing');
			freshfonecalls.disableCallButton();
			if (previewMode()) {
				freshfonewidget.enablePreviewMode();
			}
			var dontUpdateCallCount = previewMode() || recordingMode();
			freshfoneuser.publishLiveCall(dontUpdateCallCount);
			freshfonecalls.onCallStopSound();
		});

		Twilio.Device.disconnect(function (conn) {
			console.log("Call disconnected");
			freshfoneNotification.resetJsonFix();
			ffLogger.log({'action': "Call ended", 'params': conn.parameters});
			if (freshfonecalls.tConn) {
				var callSid = freshfonecalls.tConn.parameters.CallSid;
				var detail = callSid ? callSid : 'To :: '+ freshfonecalls.tConn.message.PhoneNumber;
				ffLogger.logIssue("Freshfone Call :: " + detail);
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
			} else if (!freshfonecalls.dontShowEndCallForm()) {
				var in_call_time = parseInt($(freshfonetimer.timerElement).data('runningTime') || 0, 10)
				if ( in_call_time < 3){ // less than 3 seconds is an invalid case.
					freshfonewidget.handleWidgets('outgoing');
					freshfoneuser.resetStatusAfterCall();
					freshfoneuser.updatePresence();					
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
			ffLogger.log({'action': "Incoming Call Notification", 'params': conn.parameters});
			freshfoneNotification.anyAvailableConnections(conn);
			var freshfoneConnection = new FreshfoneConnection(conn);
			freshfoneConnection.incomingAlert();
        });

		Twilio.Device.presence(function (pres) {
		});
	}
	});
}(jQuery));
