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
		freshfoneSupervisorCall,
		incomingNotification;
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
		incomingNotification = new IncomingNotification();

		freshfonesocket.loadDependencies(freshfonecalls,freshfoneNetworkError);
		freshfoneuser.loadDependencies(freshfonecalls,freshfonesocket,freshfoneNotification, incomingNotification);
		freshfonecalls.loadDependencies(freshfoneuser, freshfonetimer, freshfoneUserInfo, freshfonesocket);
		freshfonewidget.loadDependencies(freshfonecalls, freshfoneuser, freshfoneSupervisorCall);
		freshfoneendcall.loadDependencies(freshfonecalls, freshfoneuser, freshfonewidget);
		freshfoneNotification.loadDependencies(freshfonecalls, freshfoneUserInfo);
		incomingNotification.loadDependencies(freshfonecalls, freshfoneUserInfo);
		freshfoneNetworkError.loadDependencies(freshfonewidget,freshfonecalls,freshfoneuser);
		freshfoneSupervisorCall.loadDependencies(freshfonecalls,freshfonewidget,freshfonetimer,freshfoneuser);
		window.ffLogger = new FreshfoneLogger();
	});
	// End ongoing call
	$(document).on('click', '.end_call', function (e) {
		e.preventDefault();
		var dontShowForm = freshfonecalls.endCallFormForConference();
		freshfonecalls.hangup();
		freshfoneDialpadEvents.hideContactDetails();
		//Checking isAgentConference and isWarmTransfer when freshfonecalls init() is called in hangup()
		if (freshfonecalls.dontShowEndCallForm() || dontShowForm) {
			freshfoneuser.resetStatusAfterCall();
			freshfoneuser.updatePresence();
			return freshfonewidget.handleWidgets();
		}
		freshfoneendcall.showEndCallForm();
	});
}(jQuery));