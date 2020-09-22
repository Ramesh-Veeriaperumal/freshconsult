window.App = window.App || {};
window.App.Freshfonedashboard = window.App.Freshfonedashboard || {};
(function($){
		"use strict";
		window.App.Freshfonedashboard.SupervisorCallUpdate = {
		init: function() {
			this.bindJoinCall();
			this.bindEndCall();
			this.bindSocketEvents();
			$("#freshfone_active_calls").find(".supervised").each(function()
										{this.textContent = freshfone.oncall;});
			this.updateCurrentSupervisorCallUI();
		},
		bindSocketEvents: function()
		{
			this.bindDisableSupervisorCall();
			this.bindEnableSupervisorCall();
		},
		bindJoinCall: function () {
			var self = this;
			$("body").on('click.supervisor_events', '.call_to_join',
			function(ev){
				return self.joinCallAsSupervisor($(this).data("callid"));
			});
		},
		bindEndCall: function () {
			$("body").on('click.supervisor_events', '.call_joined',
			function(ev){
				ev.preventDefault();
				freshfonecalls.hangup();
			});
		},
		joinCallAsSupervisor: function(callId) {
			if(this.canSupervisorConnect()){
				this.rejectActiveConnections();
				$("#freshfone_active_calls").find('.call_to_join').addClass("disabled");
				freshfoneSupervisorCall.connectSupervisor(callId);
				freshfonewidget.minimiseChatWidget();
			} else {
				this.resetJoinCallButton(callId);
			}
		},
		canSupervisorConnect: function(){
			return (Twilio.Device.status() !== 'busy' && freshfoneuser.isOnlineOrOffline());
		}, 
		rejectActiveConnections: function(){
			if(Twilio.Device.activeConnection() && 
					Twilio.Device.activeConnection().status() == 'pending')
			{
				freshfoneNotification.removeAllOngoingNotifications();
			}
		},
		resetSupervisorCallDetails: function() {
			$("#freshfone_active_calls").find('.call_to_join').removeClass("disabled");
			this.resetCurrentSupervisorCallUI();
		},
		updateCurrentSupervisorCallUI : function() {
			var $elm = this.getCallRow(freshfoneSupervisorCall.supervisorCallId);
			$elm.find('.call_to_join')
					.removeClass('call_to_join disabled supervised')
					.addClass('call_joined')
					.each(function() 
						{this.textContent = freshfone.leave;
					});
		},
		resetCurrentSupervisorCallUI : function() {
			var $elm = this.getCallRow(freshfoneSupervisorCall.supervisorCallId);
			$elm.find('.call_joined')
					.removeClass('call_joined')
					.addClass('call_to_join')
					.each(function()
						{this.textContent = freshfone.join;
					});
		},
		resetJoinCallButton : function(callId) {
			var $elm = this.getCallRow(callId);
			$elm.find('.call_to_join').removeClass('disabled');
		},
		bindDisableSupervisorCall: function() {
			var self = this;
			$("body").on('disable_supervisor_call.supervisor_events', "#freshfone_dashboard_events",
			function(ev, data){
				var $elm = self.getCallRow(data.call_details.call_id);
				$elm.find('.call_to_join')
						.addClass('supervised')
						.each(function() {
							this.textContent = freshfone.oncall;
						});
			});
		},
		bindEnableSupervisorCall: function() {
		var self = this;
			$("body").on('enable_supervisor_call.supervisor_events', "#freshfone_dashboard_events",
			function(ev, data){
				var $elm = self.getCallRow(data.call_details.call_id);
				$elm.find('.call_to_join')
						.removeClass('supervised')
						.each(function()
							{this.textContent = freshfone.join;
						});
			});
		},
		getCallRow : function(id)	{
			var callRow = App.Freshfonedashboard.activeCallsList.get('call_id', id);
			var elm = callRow ? callRow.elm : null;
			return $(elm);
		},
		leave: function() {
			$("body").off('.supervisor_events');
		} 
	}
})(window.jQuery);