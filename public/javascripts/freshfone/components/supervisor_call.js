var FreshfoneSupervisorCall;
(function ($) {
	"use strict";
	FreshfoneSupervisorCall = function() {
		this.init();
	};
	FreshfoneSupervisorCall.prototype = {
		init: function () {
			var self=this;
			this.isSupervisorOnCall = false;
			this.isSupervisorConnected = false;
			this.supervisorCallId = null;
			this.isSupervisorMute = true;
      		this.bindJoinCall();
      		this.bindEndCall();
      		this.bindMute();
      		this.bindSocketEvents();
      		$("#freshfone_active_calls").find(".supervised").each(function(){this.innerText = freshfone.oncall;});
		},
		bindSocketEvents: function()
		{
			this.bindDisableSupervisorCall();
      		this.bindEnableSupervisorCall();
		},
		loadDependencies: function (freshfonecalls,freshfonewidget,freshfonetimer,freshfoneuser) {
			this.freshfonecalls = freshfonecalls;
			this.freshfonewidget = freshfonewidget;
			this.freshfonetimer = freshfonetimer;
			this.freshfoneuser = freshfoneuser;
		},
		intializeWidgets : function(){
			this.$supervisorCallContainer = $('.supervisor_call_details');
			this.$supervisorCallinfo = $('#supervisor_call_info');
			this.supervisorCallWidget = freshfonewidget.widget.find('.supervisor');
		},
		startCallTimer : function(){
			freshfonetimer.startCallTimer( $("#supervisor_call_timings") );
	   	},
		bindJoinCall: function () {
			var self = this;
      		$("#freshfone_active_calls").on('click.join_call_btn', '.call_to_join',
      		function(ev){
        		return self.joinCallAsSupervisor($(this).data("callid"));
      		});
    	},
    	bindEndCall: function () {
      		$("#freshfone_active_calls").on('click.join_call_btn', '.call_joined',
      		function(ev){
        		ev.preventDefault();
        		freshfonecalls.hangup();
      		});
      		$("body").on('click', '.end_supervisor_call', function (e) {
				e.preventDefault();
				freshfonecalls.hangup();
			});
    	},
    	bindMute: function () {
    		var self=this;
    		$('#unmute').click(function () { 
    			$(this).addClass('loading');
    			self.handleMute(); 
    		});
    	},
		joinCallAsSupervisor: function(callId) {
			if (Twilio.Device.status() !== 'busy') {
				if (freshfoneuser.isBusy()) { return; }
				if(Twilio.Device.activeConnection() && Twilio.Device.activeConnection().status() == 'pending')
				{
					freshfoneNotification.removeAllOngoingNotifications();
				}
				$("#freshfone_active_calls").find('.call_to_join').addClass("disabled");
				this.isSupervisorOnCall = true;
				this.isSupervisorMute = true;
				this.supervisorCallId = callId;
				var params = { PhoneNumber : freshfonecalls.number, phone_country: freshfonecalls.callerLocation(),
						number_id: freshfonecalls.outgoingNumberId(), agent: freshfonecalls.currentUser, type: "supervisor", call: callId };
				freshfonecalls.actionsCall(function () { Twilio.Device.connect(params); } );
				freshfonecalls.setDirectionOutgoing();
			} else {
				this.resetJoinCallButton(callId);
			}
		},
		handleConnect : function() {
			this.isSupervisorConnected = true;
	   		this.updateCurrentSupervisorCallUI();
			freshfonewidget.handleWidgets('supervisor');
	   	},
	   	showWidgets: function () {
	   		this.supervisorCallWidget.show();
			this.populateSupervisorCallContainer();
			this.$supervisorCallContainer.show();
		},
		hideWidgets: function () {
	   		this.supervisorCallWidget.hide();
			this.$supervisorCallContainer.hide();
		},
		populateSupervisorCallContainer: function () {
			var selectedCallDom = App.Freshfonedashboard.activeCallsList.get("call_id",this.supervisorCallId);
			selectedCallDom._values["caller_name"] = selectedCallDom._values["caller_name"].replace("contact-hover","");
			selectedCallDom._values["agent_name"] = selectedCallDom._values["agent_name"].replace("contact-hover","");
			var temp = $("#supervisor_call_info_template").clone();
      		this.$supervisorCallinfo.html(temp.tmpl(selectedCallDom._values));
		},
		resetSupervisorCallDetails: function() {
			$("#freshfone_active_calls").find('.call_to_join').removeClass("disabled");
			this.resetCurrentSupervisorCallUI();
			this.isSupervisorOnCall = false;
			this.supervisorCallId = null;
		},
	   	updateCurrentSupervisorCallUI : function() {
	   		var self = this;
	   		var $elm = this.getCallRow(this.supervisorCallId);
       		if($elm != null){
       			$elm.find('.call_to_join').each(function(){this.innerText = freshfone.leave;});
       			$elm.find('.call_to_join').removeClass('call_to_join').addClass('call_joined').removeClass("disabled");;
       		}
	   	},
	   	resetCurrentSupervisorCallUI : function() {
	   		var self = this;
	   		var $elm = this.getCallRow(this.supervisorCallId);
       		if($elm != null){
       			$elm.find('.call_joined').each(function(){this.innerText = freshfone.join ;});
       			$elm.find('.call_joined').removeClass('call_joined').addClass('call_to_join');
       		}
	   	},
	   	resetJoinCallButton : function(callId) {
	   		var $elm = this.getCallRow(callId);
       		if($elm != null){
       			$elm.find('.call_to_join').removeClass('disabled');
       		}
	   	},
	   	bindDisableSupervisorCall: function() {
	   		var self = this;
     		$("body").on('disable_supervisor_call.freshfone_dashboard', "#freshfone_dashboard_events", function(ev, data){
     			var $elm = self.getCallRow(data.call_details.call_id);
       			if($elm != null){
       				$elm.find('.call_to_join').addClass('supervised').each(function(){this.innerText = freshfone.oncall;});
       			}
     		});
     	},
       	bindEnableSupervisorCall: function() {
       		var self = this;
     		$("body").on('enable_supervisor_call.freshfone_dashboard', "#freshfone_dashboard_events", function(ev, data){
       			var $elm = self.getCallRow(data.call_details.call_id);
       			if($elm != null){
       				$elm.find('.call_to_join').removeClass('supervised').each(function(){this.innerText = freshfone.join;});;
       			}
     		});
     	},
     	handleMute: function () {
     		this.isSupervisorMute = this.isSupervisorMute ? false : true ;
			this.muteUnmuteSupervisor();
		},
	   	muteUnmuteSupervisor: function () {
          var self = this;
          $.ajax({
            dataType: "json",
            data: { "call": self.supervisingCallId, "number_id": freshfonecalls.outgoingNumberId(),
            		 "isMute": self.isSupervisorMute, "call": self.supervisorCallId },
            url: '/phone/dashboard/mute',
            type: 'POST',
           	success: function(data) {
           		self.updateMuteUI();
            },
        	error: function () {
        		this.isSupervisorMute = this.isSupervisorMute ? false : true ;
        		self.updateMuteUI();
        	}	
         });
       	},
       	updateMuteUI : function()
       	{
           	$("#unmute").removeClass('loading');
       		this.isSupervisorMute ? $("#unmute").removeClass('active').attr('title',freshfone.unmute) :
       		 							 $("#unmute").addClass('active').attr('title',freshfone.mute);
       	},
	   	resetToDefaultState : function()  {
			freshfonewidget.resetToDefaultState();
			this.resetSupervisorCallDetails();		
			freshfoneuser.resetStatusAfterCall();
			freshfoneuser.updatePresence();
			freshfonecalls.init();
			freshfoneuser.init();
	   	},
	   	getCallRow : function(id)	{
	   		var callRow = App.Freshfonedashboard.activeCallsList.get('call_id', id);
       		if(typeof callRow != "undefined" && callRow != null && callRow.elm != null ) 
       		{
       			return $(callRow.elm);
       		}
       		return null;
	   	}
	};
}(jQuery));