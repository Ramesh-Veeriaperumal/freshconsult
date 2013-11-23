(function ($) {
    "use strict";
	freshfoneuser.initializeDevice();


	if (typeof (Twilio) !== "undefined") {
		Twilio.Device.ready(function (device) {
			if(freshfonecalls.lastAction){
				freshfonecalls.lastAction();
			}
		});

		Twilio.Device.error(function (error) {
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
			if ((freshfonecalls.tConn.message|| {}).record) {
				freshfonecalls.setRecordingState();
				return;
			}
			$("#log").text("Successfully established call");
			freshfoneNotification.resetJsonFix();
			freshfoneNotification.popAllNotification(conn);
			freshfonetimer.startCallTimer();
			freshfoneuser.publishLiveCall();
			freshfonewidget.handleWidgets('ongoing');
			freshfonecalls.disableCallButton();
			if ((freshfonecalls.tConn.message || {}).preview) {
				freshfonewidget.enablePreviewMode();
			}
		});

		/* Log a message when a call disconnects. */
		Twilio.Device.disconnect(function (conn) {
			$("#log").text("Call ended");
			freshfoneNotification.resetJsonFix();
			if ((freshfonecalls.tConn.message || {}).record) {
				return freshfonecalls.fetchRecordedUrl();
			}
			freshfonetimer.stopCallTimer();
			freshfonecalls.enableCallButton();
			if ((freshfonecalls.tConn.message || {}).preview) {
				freshfonewidget.resetPreviewMode();
				freshfonewidget.resetPreviewButton();
				return freshfonewidget.handleWidgets('outgoing');
			}
			
			freshfonecalls.tConn = conn;
			if (freshfonecalls.hasUnfinishedAction()) {
				return;

			} else if (!freshfonecalls.dontShowEndCallForm()) {
				freshfoneendcall.showEndCallForm();
				
			} else {
				freshfonecalls.transferSuccessFlash();
				freshfoneuser.resetStatusAfterCall();
				freshfoneuser.updatePresence();
				freshfonewidget.resetToDefaultState();
				freshfonecalls.init();
				freshfoneuser.init();
			}
			freshfonecalls.lastAction = null;
			freshfonewidget.hideTransfer();
		});

		Twilio.Device.cancel(function (conn) {
			$("#log").text("Ready");
			// freshfonecalls.enableCallButton();
			freshfoneNotification.closeConnetions(conn);
		});

		Twilio.Device.incoming(function (conn) {
			$("#log").text("Incoming connection from " + conn.parameters.From);
			// freshfonecalls.disableCallButton();
			freshfoneNotification.anyAvailableConnections(conn);
		});

		Twilio.Device.presence(function (pres) {
		});
	}
}(jQuery));
