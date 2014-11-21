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
			freshfonetimer.resetCallTimer();
			freshfoneNotification.resetJsonFix();
			freshfoneNotification.popAllNotification();
			freshfonecalls.resetRecordingState();
			freshfonewidget.resetPreviewButton();
			if ($.inArray(error.code, [400, 401, 31205]) > -1) {
				freshfoneuser.getCapabilityToken();
			}
			freshfonecalls.error = error;
			freshfonecalls.errorcode = error.code;
			// error.code 400 --->> invalid access token
			// error.code 401 --->> This AccessToken is no longer valid
			
		});

		Twilio.Device.connect(function (conn) {
			freshfonecalls.tConn = conn;
			if(!freshfonecalls.isOutgoing()) { freshfoneNotification.initializeCall(conn); }
			freshfonecalls.errorcode = null;
			freshfonecalls.lastAction = null;
			freshfonecalls.transfered = false;
			if (recordingMode()) { return freshfonecalls.setRecordingState(); }
			$("#log").text("Successfully established call");
			freshfoneNotification.resetJsonFix();
			freshfoneNotification.popAllNotification(conn);
			freshfonetimer.startCallTimer();
			freshfonewidget.toggleWidgetInactive(false);
			freshfonewidget.handleWidgets('ongoing');
			freshfonecalls.disableCallButton();
			if (previewMode()) {
				freshfonewidget.enablePreviewMode();
			}
			var dontUpdateCallCount = previewMode() || recordingMode();
			freshfoneuser.publishLiveCall(dontUpdateCallCount);
			freshfonesocket.bindTransfer();
			freshfonecalls.onCallStopSound();
		});

		/* Log a message when a call disconnects. */
		Twilio.Device.disconnect(function (conn) {
			$("#log").text("Call ended");
			freshfoneNotification.resetJsonFix();
			if (recordingMode()) {
				return freshfonecalls.fetchRecordedUrl();
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
				freshfoneendcall.showEndCallForm();
			} else {
				freshfonecalls.init();
				freshfoneuser.init();
			}
			freshfonecalls.lastAction = null;
			freshfonewidget.hideTransfer();
		});

		Twilio.Device.cancel(function (conn) {
			$("#log").text("Ready");
			// freshfonecalls.enableCallButton();
			freshfoneNotification.closeConnections(conn);
		});

		Twilio.Device.incoming(function (conn) {
			$("#log").text("Incoming connection from " + conn.parameters.From);
			// freshfonecalls.disableCallButton();
			
			freshfoneNotification.anyAvailableConnections(conn);
			var freshfoneConnection = new FreshfoneConnection(conn);
			freshfoneConnection.incomingAlert();
        });

		Twilio.Device.presence(function (pres) {
		});
	}
	});
}(jQuery));
