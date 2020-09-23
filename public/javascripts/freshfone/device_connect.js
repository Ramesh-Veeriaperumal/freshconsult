var TwilioConnect;
(function($) {
  "use strict"
  TwilioConnect = function (conn, notification) {
    this.notification = notification;
    this.init(conn);
  };

  TwilioConnect.prototype = {
    init : function(conn){
      this.deviceConnectActions(conn);
    },
    deviceConnectActions : function(conn){
      freshfonecalls.tConn = conn;
      if(!this.isOutgoingCall()) { 
        this.notification.initializeCall(conn);
      }
      freshfonecalls.resetFlags();
      if (this.recordingMode()) { 
        return freshfonecalls.setRecordingState(); 
      }
      freshfoneNotification.resetJsonFix();
      if(this.isOutgoingCall()){
          $('#number').intlTelInput("updatePreferredCountries");
          freshfonecalls.registerCall(conn.parameters.CallSid);
       } 
      this.initializeAccept(conn);
      this.handleSupervisorCalls();
      freshfonecalls.disableCallButton(); 
      this.handlePreviewMode();
      this.acceptAck(conn);
      this.handleCallQualityMetrics(conn);
    },
    
    previewMode : function() { 
      return (freshfonecalls.tConn.message || {}).preview; 
    },
    
    recordingMode : function() { 
      return (freshfonecalls.tConn.message || {}).record; 
    },
    
    isOutgoingCall : function() {
      return freshfonecalls.isOutgoing();
    },

    isIncoming: function(){
      return !this.isOutgoingCall();
    },
    
    handleCallQualityMetrics : function(conn){
      freshfonecalls.freshfone_monitor = new window.FreshfoneMonitor(conn);
      if(freshfonecalls.canTrackQuality())
        freshfonecalls.freshfone_monitor.startLoggingWithInterval();
    },
    
    handlePreviewMode : function(){
      if (this.previewMode()) {
        freshfonewidget.enablePreviewMode();
      }
    },
    
    initializeAccept : function(conn){
      var acceptedConnection = freshfonecalls.conferenceMode ? freshfonecalls.conferenceConn : conn;
      this.notification.popAllNotification(acceptedConnection);
      if(this.notification === freshfoneNotification){
        incomingNotification.popAllNotification(acceptedConnection);              
      }
      freshfonewidget.toggleWidgetInactive(false);
      freshfonewidget.hideTransfer();
    },
    
    acceptAck : function(conn){ 
      var dontUpdateCallCount = this.previewMode() || this.recordingMode();
      var number = freshfone.newNotifications ? conn.message.number : conn.parameters.From ;
      if(!freshfonewidget.isAgentConferenceCall()){
        freshfonecalls.getSavedCallNotesAndTicket(number);
      }
      freshfoneuser.publishLiveCall(dontUpdateCallCount);
      freshfonecalls.onCallStopSound();
    },
    
    handleSupervisorCalls : function(){
      if(freshfoneSupervisorCall.isSupervisorOnCall){
        freshfoneSupervisorCall.startCallTimer();
        freshfoneSupervisorCall.handleConnect();
      } 
      else {
        freshfonetimer.startCallTimer();
        if(this.canShowWidget()) {
          freshfonewidget.handleWidgets('ongoing');
        }
      }
    },
    canShowWidget : function(){
      return !(freshfone.newNotifications && this.isIncoming()) || freshfonecalls.isAgentConference;
    }

  };

}(jQuery));
