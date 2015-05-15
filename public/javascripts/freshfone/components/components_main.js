var freshfonetimer,
		freshfonecalls,
		freshfoneuser,
		freshfonewidget,
		freshfonesocket,
		freshfoneendcall,
		freshfoneUserInfo,
		freshfoneNotification,
		freshfoneNetworkError;
(function ($) {
	"use strict";
	$(document).ready(function() {
		freshfonetimer = new FreshfoneTimer();
		freshfoneUserInfo = new FreshfoneUserInfo();
		freshfonesocket = new FreshfoneSocket();
		freshfoneuser = new FreshfoneUser();
		freshfonecalls = new FreshfoneCalls();
		freshfonewidget = new FreshfoneWidget();
		freshfoneendcall = new FreshfoneEndCall();
		freshfoneNotification = new FreshfoneNotification();
		freshfoneNetworkError = new FreshfoneNetworkError();

		freshfonesocket.loadDependencies(freshfonecalls,freshfoneNetworkError);
		freshfoneuser.loadDependencies(freshfonecalls,freshfonesocket,freshfoneNotification);
		freshfonecalls.loadDependencies(freshfoneuser, freshfonetimer, freshfoneUserInfo);
		freshfonewidget.loadDependencies(freshfonecalls, freshfoneuser);
		freshfoneendcall.loadDependencies(freshfonecalls, freshfoneuser, freshfonewidget);
		freshfoneNotification.loadDependencies(freshfonecalls, freshfoneUserInfo);
		freshfoneNetworkError.loadDependencies(freshfonewidget,freshfonecalls,freshfoneuser);
		window.ffLogger = new FreshfoneLogger();
	});
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