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
			this.bindMute();
			this.bindEndCall();
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
    bindEndCall: function () {
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
    connectSupervisor : function(callId){
      this.isSupervisorOnCall = true;
      this.supervisorCallId = callId;
      var params = { PhoneNumber : freshfonecalls.number, phone_country: 
        freshfonecalls.callerLocation(), number_id: freshfonecalls.outgoingNumberId(),
        agent: freshfonecalls.currentUser, type: "supervisor", call: callId };
      freshfonecalls.actionsCall(function () { Twilio.Device.connect(params); });
      freshfonecalls.setDirectionOutgoing();
    },
		handleConnect : function() {
			this.isSupervisorConnected = true;
			App.Freshfonedashboard.SupervisorCallUpdate.updateCurrentSupervisorCallUI();
			freshfonewidget.handleWidgets('supervisor');
	   	},
	   	showWidgets: function () {
	   		this.supervisorCallWidget.show();
			this.populateSupervisorCallContainer();
			this.$supervisorCallContainer.show();
			freshfonewidget.bindPageClose();
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
	   		    App.Freshfonedashboard.SupervisorCallUpdate.updateCurrentSupervisorCallUI();
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
			App.Freshfonedashboard.SupervisorCallUpdate.resetSupervisorCallDetails();		
			this.isSupervisorOnCall = false;
			this.isSupervisorConnected = false;
			this.supervisorCallId = null;
			this.isSupervisorMute = true;
			freshfoneuser.resetStatusAfterCall();
			freshfoneuser.updatePresence();
			freshfonecalls.init();
			freshfoneuser.init();
	   	},
	   	resetJoinCallButton: function(){
	   		App.Freshfonedashboard.SupervisorCallUpdate.resetJoinCallButton();
	   }
	};
}(jQuery));