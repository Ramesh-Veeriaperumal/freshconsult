var IncomingNotification;
(function($) {
  "use strict"
  var incomingConnections = {},
    ongoingNotifications = {},
    onholdNotifications = [],
    MAX_PARALLEL_NOTIFICATIONS = 3,
    acceptedConnection = null; //RESET this after call

  IncomingNotification = function () {
    this.init();
    this.originalJsonStringify = JSON.stringify;
    this.isChrome = ($.browser.webkit && navigator.userAgent.indexOf('Chrome') >= -1);
    this.isOriginal = true;
    this.bindPjaxTitleChange();
    this.alertTitle="Incoming Call..";
    this.originalTitle = document.title;
    this.desktopNotification = false;
    this.rejectableConnections = [];
  };

  IncomingNotification.prototype = {
    init: function () { 
      this.observeNotification();
      this.notifyTabsFlag=false;
    },
    loadDependencies: function (freshfonecalls, freshfoneUserInfo) {
      this.freshfonecalls = freshfonecalls;
      this.freshfoneUserInfo = freshfoneUserInfo;
    },
    notify: function (incomingCall) {
      var incomingConnection = new IncomingConnection(incomingCall, this);
      incomingConnections[incomingCall.call_id] = incomingConnection;
      if (Object.keys(incomingConnections).length <= MAX_PARALLEL_NOTIFICATIONS) {
        this.pushOngoingNotification(incomingConnection);
      } else {
        this.pushOnholdNotifications(incomingConnection);
      }
    },
    setAcceptedConnection: function (connection) {
      acceptedConnection = connection;
    },
    currentConnection: function () {
      return acceptedConnection;
    },
    resetAcceptedConnection: function () {
      acceptedConnection = null;
    },
    setDirectionIncoming: function () {
      this.freshfonecalls.setDirectionIncoming();
    },

    pushOngoingNotification: function (incomingConnection) {
      var self = this;
      ongoingNotifications[incomingConnection.callId()] = incomingConnection;
      if (!this.notifyTabsFlag) {
        this.notifyTabs();
        this.bindResetTitle();
      }
      incomingConnection.createNotification();
    },

    popOngoingNotification: function (call_id) {
      this.removeNotification(call_id);
      this.popOnholdNotifications();
    },

    removeNotification: function (call_id) {
      this.destroy(call_id);
      if (!Object.keys(ongoingNotifications).length) { 
        this.resetTitle(); 
      }
    },

    pushOnholdNotifications: function (freshfoneConnection) {
      onholdNotifications.push(freshfoneConnection);
    },

    popOnholdNotifications: function () {
      if (onholdNotifications.length) {
        this.pushOngoingNotification(onholdNotifications.shift());
      }
    },

    deleteOnholdNotifications: function (freshfoneConnection) {
      if (freshfoneConnection) {
        this.removeFromOnholdNotifications(freshfoneConnection);
      }
    },

    popAllNotification: function (conn) {
      this.removeAllOnholdNotifications();
      this.removeAllOngoingNotifications();
      this.resetTitle();
      this.updateRejectResponse();
    },

    removeFromOnholdNotifications: function (freshfoneConnection) {
      var index = onholdNotifications.indexOf(freshfoneConnection);
      if (~index) { onholdNotifications.splice(index, 1); }
      this.deleteNotification(freshfoneConnection.connection, freshfoneConnection);
    },

    removeAllOnholdNotifications: function () {
      var self = this;
      var callId;
      $.each(onholdNotifications, function (i, freshfoneConnection) {
        self.removeNotification(freshfoneConnection.callId());
        if (!acceptedConnection || freshfoneConnection.callId() !== acceptedConnection.callId()) {
          freshfoneConnection.rejectAll();
          self.addToRejectableConnections(freshfoneConnection);
        }
      });
      onholdNotifications = [];
    },

    removeAllOngoingNotifications: function () {
      var self = this;
      var acceptedCallId;
      $.each(ongoingNotifications, function (i, freshfoneConnection) {
        self.removeNotification(freshfoneConnection.callId());
        if (!acceptedConnection || freshfoneConnection.callId() !== acceptedConnection.callId()) { 
          freshfoneConnection.rejectAll();
          self.addToRejectableConnections(freshfoneConnection);
        }
      });
      ongoingNotifications = {};
    },

    destroy: function (call_id) {
      var currentConnection = ongoingNotifications[call_id];
      if(currentConnection) {
        currentConnection.destroy();
        delete ongoingNotifications[call_id];
      }
    },

    notifyTabs: function () {
      var self = this;
      self.notifyTabsFlag=true;
      self.interval = setInterval(function () {
        document.title = self.isOriginal ? self.originalTitle : self.alertTitle;
        self.isOriginal = !self.isOriginal;
      }, 1000);
    },

    bindResetTitle: function () {
      var self = this;
      $(document).on('hover.freshfone', function () {
        self.resetTitle();
      });
    },

    bindPjaxTitleChange: function () {
      $('body').on('pjaxDone', function() {
        self.originalTitle = document.title;
      });
    },

    resetTitle: function(){
      var self = this;
      clearInterval(self.interval);
      document.title = self.originalTitle;
      $(document).die('hover.freshfone');
      self.notifyTabsFlag=false;
    },

    initializeCall: function (conn) {
      var freshfoneConnection = acceptedConnection;
      this.resetAcceptedConnection();
      this.freshfonecalls.fetchCallerDetails({
        number: freshfoneConnection.customerNumber,
        callerName : freshfoneConnection.callerName,
        callerId : freshfoneConnection.callerId });
      this.freshfonecalls.disableCallButton();
      this.freshfonecalls.transfered = false;
      this.setOngoingStatusAvatar($(freshfoneConnection.avatar));
      this.freshfoneUserInfo.customerNumber = freshfoneConnection.customerNumber;
      this.freshfoneUserInfo.setOngoingCallContext(freshfoneConnection.callerCard); 
    },

    userInfo: function (number, freshfoneConnection) {
      this.freshfoneUserInfo.userInfo(number, false);
    },

    setOngoingStatusAvatar: function (avatar) {
      this.freshfoneUserInfo.setOngoingStatusAvatar(avatar);
    },

    prefillContactTemplate: function (params, filler) {
      this.freshfoneUserInfo.prefillContactTemplate(params, filler);
    },

    setRequestObject: function(freshfoneConnection) {
      this.freshfoneUserInfo.setRequestObject(freshfoneConnection);
    },

    canAllowUserPresenceChange: function () {
      if (Object.keys(ongoingNotifications).length > 0){ return true; }
    },
    
    getIncomingConnection: function (CallId) {
      return incomingConnections[CallId];
    },
    setTransferMeta: function (type, agent){
      this.freshfoneUserInfo.setTransferMeta(type, agent);
    },
    ringingTone: function(sound){
      var self = this;
      sound.play({
        onfinish: function() {
         self.ringingTone(sound);
        }
      });
    },
    playRingingTone : function(call_id){
      var self = this;
      var key = "call_ringing_sound";
      if(!$.cookie(key)){
        if(freshfone.callRingingSound.playState === 0){
          self.ringingTone(freshfone.callRingingSound);
          incomingConnections[call_id].freshfoneNotification.desktopNotification = true;
        }
      }
      else{
        self.desktopNotification = false;
      }
      var expire = new Date();
      expire.setTime(expire.getTime() + (5 * 1000));
      $.cookie(key, true, {path:'/', expires: expire});
    },
    stopRingingTone : function(){
      freshfone.callRingingSound.stop();
    },
    addToRejectableConnections: function(connection){
      this.rejectableConnections.push(connection);
    },
    updateRejectResponse: function(){
      if(!this.rejectableConnections.length){
        return;
      }
      var data = {CallStatus: 'busy', call_ids: [], user_id: freshfone.current_user};
      $.each(this.rejectableConnections, function(index, connection){
        if(data.call_ids.indexOf(connection.callId()) == -1){
          data.call_ids.push(connection.callId());
        }
      });
      this.rejectableConnections[this.rejectableConnections.length - 1].updatePingedAgentStatus(data);
      this.rejectableConnections = [];
    },
    observeNotification: function(){
      if(freshfone.newNotifications){
        var self = this;
        $('.notifier').livequery(function() { self.onNotificationInsert($(this).attr("id")); }, 
                                 function() { self.onNotificationRemoval($(this).attr("id")); } );
      }
    },
    onNotificationInsert: function(call_id){
      if(incomingConnections[call_id]){
        this.playRingingTone(call_id);
        incomingConnections[call_id].startRingingTime();
        incomingConnections[call_id].createDesktopNotification();
      }
    },
    onNotificationRemoval: function(call_id){
      if(incomingConnections[call_id]){
        if (!Object.keys(ongoingNotifications).length) { 
            this.stopRingingTone();
        }  
        incomingConnections[call_id].killRingingTimer();
        incomingConnections[call_id].removeDesktopNotification();
        delete incomingConnections[call_id];
      }
    }
};

}(jQuery));