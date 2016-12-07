var IncomingConnection;
var INCOMING_RINGING_TYPES = ['incoming', 'transfer'];
(function ($) {
  "use strict";

  IncomingConnection = function (incomingCall, freshfoneNotification) {
    this.init();
    this.incomingCall = incomingCall;
    this.freshfoneNotification = freshfoneNotification;
    this.callNotificationTimeout = false;
    this.ringingTimeout = null;
    this.notificationType = incomingCall.notification_type;
  };
  IncomingConnection.prototype = {
    init: function () {
    },
    createNotification: function () {
      var self = this;
      var $incomingCallWidget = $('#incomingWidget').clone().tmpl();
      $incomingCallWidget.attr('id', this.callId());
      $incomingCallWidget.prependTo('#freshfone_notification_container');
      this.$userInfoContainer = $('#freshfone_notification_container').find('#' + this.callId());
      this.setCustomerNumber();
      this.freshfoneNotification.setRequestObject(this);
      this.freshfoneNotification.prefillContactTemplate(this.customerNumber);
      this.bindEventHandlers();
      if(freshfonecalls.transfered) {
        freshfonewidget.resetTransferingState();
      }
      this.freshfoneNotification.userInfo(this.customerNumber, this);
    },
    startRingingTime: function () {
      var self = this;
      var data = this.incomingCall;
      this.ringingTimeout = setTimeout(function () {
        self.freshfoneNotification.popOngoingNotification(self.callId());
        self.handleRingingTimeout(data);
      }, self.ringingTime());
    },
    ringingTime: function () {
      if(this.isRingingType()){
        return (freshfone.ringingTimeOutHash[this.incomingCall.number_id] * 1000);
      }
      return (freshfone.rrTimeOutHash[this.incomingCall.number_id] * 1000);
    },
    isRingingType: function(){
      return INCOMING_RINGING_TYPES.includes(this.notificationType);
    },
    handleRingingTimeout: function (data) {
      data.CallStatus = 'no-answer';
      data.call_ids = [this.callId()];
      this.updatePingedAgentStatus(data);
    },
    killRingingTimer: function () {
      clearTimeout(this.ringingTimeout);
    },
    handleRingingReject: function (data) {
      data.CallStatus = 'busy';
      data.call_ids = [this.callId()];
      this.updatePingedAgentStatus(data);
    },
    updatePingedAgentStatus: function (data) {
      data.agent = freshfone.current_user;
      $.ajax({
        type: 'PUT',
        url:'/freshfone/agent_leg/agent_response',
        data: data,
        success: function(result){
          if(result.status == 'failure'){
            ffLogger.logIssue('Agent Response Update Failure', data, 'failure');
          }
        },
        error: function (jqXHR, textStatus, errorThrown) {
          ffLogger.logIssue("Agent Response Update Failure ", {
          "error": errorThrown, textStatus: textStatus, jqXHR: jqXHR}, 'error');
        }
      });
    },
    bindEventHandlers: function () {
      var self = this;
      this.$userInfoContainer.one('click','#reject_call', function () {
        self.reject();
      });
      this.$userInfoContainer.one('click','#accept_call', function () {
        App.Phone.Metrics.setCallDirection("incoming");
        App.Phone.Metrics.resetConvertedToTicket();
        self.$userInfoContainer.find("#accept_call .ff-phone-accept-text").text("Accepting...");
        self.$userInfoContainer.off('click','#reject_call');
        self.accept();
      });
    },
    accept: function () {
      this.canAcceptCall();
    },
    reject: function () {
      this.freshfoneNotification.popOngoingNotification(this.callId());
      freshfonesocket.notify_ignore(this.callId());
      var data = this.incomingCall;
      this.handleRingingReject(data);
    },
    rejectAll: function(){
      this.freshfoneNotification.popOngoingNotification(this.callId());
      freshfonesocket.notify_ignore(this.callId());
    },
    callSid: function() {
      return this.incomingCall.call_sid;
    },
    callId: function() {
      return this.incomingCall.call_id;
    },
    setCustomerNumber: function () {
      this.customerNumber = this.incomingCall.number;
    },
    destroy: function () {
      var self = this;
      if (this.$userInfoContainer) {
        this.$userInfoContainer.hide('fast', function () {
          self.$userInfoContainer.remove();
          self.$userInfoContainer = null;
        });
      }
    },
    canAcceptCall: function () {
      var self = this;
      $.ajax({
        type: 'GET',
        dataType: "json",
        url: '/freshfone/call/inspect_call',
        data: { "call_sid": this.incomingCall.call_sid, "call": this.callId() },
        success: function (data) { 
          if(data.can_accept) {
            self.freshfoneNotification.setDirectionIncoming();
            self.setWarmTransferCall(data);
            self.connect();
            freshfonetimer.resetCallTimer();
            freshfonewidget.handleWidgets('ongoing');
          }else{
            self.reject();
          }
        },
        error: function () {
          ffLogger.logIssue("Unable accept the incoming call for "+ freshfone.current_user_details.id, { "params" : data });
         }
      });
    },
    setWarmTransferCall: function(data) {
      if(data.warm_transfer) {
        freshfonecalls.setWarmTransfer(data.warm_transfer);
      }
    },
    connect: function () {
        this.freshfoneNotification.setAcceptedConnection(this);
        var data = { call_id: this.callId(),
                     agent: freshfone.current_user,
                     account: freshfone.current_account
                    };
        freshfoneNotification.popAllNotification();
        freshfonesocket.notifyAccept(data);
        var params = {
          call: this.callId(),
          agent: freshfone.current_user,
          type: "agent_leg",
          agent_leg_type:  this.getAgentLegType(),
          number: this.incomingCall['number'],
          warm_transfer_call_id: this.getWarmTransferCallId()
        };
        var twilioConnection = Twilio.Device.connect(params);
    },
    getWarmTransferCallId: function() {
      return this.incomingCall.warm_transfer_call_id ? this.incomingCall.warm_transfer_call_id : '';
    },
    getAgentLegType:function(){
      if (this.notificationType == "warm_transfer") {
        return "agent_warm_transfer_leg";
      }
      return this.getCallType();
    },
    getCallType: function() {
      return this.notificationType == "transfer" ? "agent_transfer_leg" : "agent_leg";
    },
    createDesktopNotification: function () {
      if ( this.canCreateDesktopNotification() ) {
        try {
          this.notification = new FreshfoneDesktopNotification(this);
          this.notification.createCallWebNotification();
        }
        catch (e) {
          console.log(e);
        }
      }
    },
    removeDesktopNotification: function() {
      if(this.notification) {
        this.notification.closeWebNotification();
      }
    },
    canCreateDesktopNotification: function () {
      return (freshfonewidget.isSupportWebNotification() 
        && this.freshfoneNotification.desktopNotification );
    }
  };
}(jQuery));