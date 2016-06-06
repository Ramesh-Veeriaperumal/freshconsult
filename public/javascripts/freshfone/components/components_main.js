var freshfonetimer,
		freshfonecalls,
		freshfoneuser,
		freshfonewidget,
		freshfonesocket,
		freshfoneendcall,
		freshfoneUserInfo,
		freshfoneNotification,
		freshfoneNetworkError,
		freshfoneContactSearch,
		freshfoneDialpadEvents,
		freshfoneSupervisorCall;
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
		freshfoneContactSearch = new FreshfoneContactSearch();
		freshfoneDialpadEvents = new FreshfoneDialpadEvents();
		freshfoneSupervisorCall = new FreshfoneSupervisorCall();

		freshfonesocket.loadDependencies(freshfonecalls,freshfoneNetworkError);
		freshfoneuser.loadDependencies(freshfonecalls,freshfonesocket,freshfoneNotification);
		freshfonecalls.loadDependencies(freshfoneuser, freshfonetimer, freshfoneUserInfo);
		freshfonewidget.loadDependencies(freshfonecalls, freshfoneuser, freshfoneSupervisorCall);
		freshfoneendcall.loadDependencies(freshfonecalls, freshfoneuser, freshfonewidget);
		freshfoneNotification.loadDependencies(freshfonecalls, freshfoneUserInfo);
		freshfoneNetworkError.loadDependencies(freshfonewidget,freshfonecalls,freshfoneuser);
		freshfoneSupervisorCall.loadDependencies(freshfonecalls,freshfonewidget,freshfonetimer,freshfoneuser);
		window.ffLogger = new FreshfoneLogger();
	});
	// End ongoing call
	$(document).on('click', '.end_call', function (e) {
		e.preventDefault();
		var addAgentCall = freshfonecalls.isAgentConference;
		freshfonecalls.hangup();
		freshfoneDialpadEvents.hideContactDetails();
		//Checking isAgentConference when freshfonecalls init() is called in hangup()
		if (freshfonecalls.dontShowEndCallForm() || addAgentCall) {
			freshfoneuser.resetStatusAfterCall();
			freshfoneuser.updatePresence();
			return freshfonewidget.handleWidgets();
		}
		freshfoneendcall.showEndCallForm();
	});
}(jQuery));