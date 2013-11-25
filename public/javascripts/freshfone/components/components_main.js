var freshfonetimer,
		freshfonecalls,
		freshfoneuser,
		freshfonewidget,
		freshfonesocket,
		freshfoneendcall,
		freshfoneUserInfo,
		freshfoneNotification;
(function ($) {
	"use strict";
	freshfonetimer = new FreshfoneTimer();
	freshfoneUserInfo = new FreshfoneUserInfo();
	freshfonecalls = new FreshfoneCalls(freshfonetimer, freshfoneUserInfo);
	freshfonesocket = new FreshfoneSocket(freshfonecalls);
	freshfoneuser = new FreshfoneUser(freshfonecalls, freshfonesocket);
	freshfonewidget = new FreshfoneWidget(freshfonecalls, freshfoneuser);
	freshfoneendcall = new FreshfoneEndCall(freshfonecalls, freshfoneuser, freshfonewidget);
	freshfoneNotification = new FreshfoneNotification(freshfonecalls, freshfoneUserInfo);
	// End ongoing call
	$(document).on('click', '.end_call', function (e) {
		e.preventDefault();
		freshfonecalls.hangup();
		if (freshfonecalls.dontShowEndCallForm()) {
			freshfoneuser.resetStatusAfterCall();
			freshfoneuser.updatePresence();
			return freshfonewidget.handleWidgets();
		}
		freshfoneendcall.showEndCallForm();
	});
}(jQuery));