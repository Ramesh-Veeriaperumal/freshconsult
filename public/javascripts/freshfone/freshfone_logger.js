var FreshfoneLogger
(function ($){
  "use strict";
  FreshfoneLogger = function () {
    this.logs = {};
    this.tabId = new Date().getTime();
    this.tabs_count = -1;
    this.lastestNetConnectedAt = "";
    this.lastestNetDisconnectedAt = "";
    this.bindWindowEvents();
  };

  FreshfoneLogger.prototype = {
    log: function (logHash) {
      this.logs[Date().toString()] = logHash;
    },

    printLogs: function (object) {
      var object = (typeof object !== 'undefined') ? object : this.logs;
      console.log(JSON.stringify(object));
    },  

    logIssue: function (issue, logMessage, severity) {
      if (freshfone.isDebuggingMode == 'false' || (typeof(clientLogger) == 'undefined') ) {
        this.logs = {};
        return ;
      }
      var self = this;
      if (typeof(logMessage)== 'undefined' || logMessage == '') { logMessage = this.logs;}
      var metaData = {logs: logMessage, basic_info: this.logBasicInformation()};
      clientLogger.notifier(issue, metaData, severity || "info");
      this.logs = {};
    },

    logBasicInformation: function () {
      var flashVersion, basic_info;
      freshfonesocket.freshfone_socket_channel.emit('get_rooms_count');
      try {
        if(navigator.mimeTypes["application/x-shockwave-flash"].enabledPlugin){
          flashVersion = (navigator.plugins["Shockwave Flash 2.0"] || navigator.plugins["Shockwave Flash"]).description.replace(/\D+/g, ",").match(/^,?(.+),?$/)[1];
        }
      } catch(e) {
        clientLogger.notifyException(e);
      }

      basic_info = { 
        'Twilio Device' : {
          'status': Twilio.Device.status(),
          'incoming sound': Twilio.Device.sounds.incoming(),
          'Latest Device Token': getCookie("freshfone")
        },
        'freshfone User' : {
          'previousStatus' : userStatusReverse[freshfoneuser.previous_status],
          'status': userStatusReverse[freshfoneuser.status], 
          'avilableOnPhone': freshfoneuser.availableOnPhone,
          'online': freshfoneuser.online
        },
        'freshfone calls' : {
          'fconn_status': freshfonecalls.tConn ? freshfonecalls.tConn.status() : freshfonecalls.tConn,
          'isMute': Boolean(freshfonecalls.isMute),
          'status': callStatusReverse[freshfonecalls.status],
          'transfered': freshfonecalls.transfered
        },
         'freshfone socket' : {
            "Connected_at" : freshfonesocket.connectionCreatedAt,
            "Disconnected_at" : freshfonesocket.connectionClosedAt
         },
        'Flash version' : flashVersion,
        'Tab Id / Tab Count': this.tabId + " / " + this.tabs_count
      };
      return basic_info;
    },
    bindWindowEvents: function () {
      var self = this;
      window.addEventListener('offline', function(){
        self.lastestNetDisconnectedAt = new Date();
      });
      window.addEventListener("online", function(){
        self.lastestNetConnectedAt = new Date();
      });

    }
  };
}(jQuery));
