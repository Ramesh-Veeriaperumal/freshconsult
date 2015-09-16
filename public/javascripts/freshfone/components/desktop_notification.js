var FreshfoneDesktopNotification;
(function($) {
  "use strict";
  FreshfoneDesktopNotification = function (freshfoneConnection) {
    this.callConnection = freshfoneConnection
  };
  FreshfoneDesktopNotification.prototype = {
    init: function () {
      // this.createWebNotification();
    },
    createCallWebNotification: function () {
      var title,notificationProperties, bodyText, callMeta;
      var self = this;
      callMeta = this.callConnection.ffNumberName;
      title = "Incoming call to";
      title = callMeta ? title+ " " + callMeta : title;
      bodyText = this.getUserInfo();
      notificationProperties = {
        body: bodyText,
        icon: "/images/misc/ff-notification-icon-2x.png",
        tag: 'freshfone_'+this.callConnection.callSid()
      };
      this.notification = new Notification(title,notificationProperties);
      this.notification.onclick = function(args) { window.focus(); this.close ();};
    },
    closeWebNotification: function () {
      if(this.notification) {
      this.notification.close();
      }
    },
    bindDeskNotifierButton: function () {
      var self = this;
      console.log('bindDeskNotifierButton');
      freshfonewidget.desktopNotifierWidget.on("click", function () {
        Notification.requestPermission( function () {
          freshfonewidget.desktopNotifierWidget.hide();
        });
      });
    },
    getUserInfo: function () { 
      var callerNumber, callerName, callerDetails, bodyText;
      callerNumber = freshfoneUserInfo.formattedNumber( this.callConnection.customerNumber);
      callerName = this.callConnection.callerName;
      callerDetails = callerName ? (callerName + " (" + callerNumber +")") : callerNumber;
      bodyText = callerDetails + " from "+ freshfoneUserInfo.callerLocation(callerNumber);
      return bodyText;
    },
    createTransferNotification: function(call) {
      var title,notificationProperties, bodyText;
      var self = this;
      title = "Agent missed the transfered call";
      bodyText = "You can reconnect with your caller"
      notificationProperties = {
        body: bodyText,
        icon: "/images/misc/ff-notification-icon-2x.png",
        tag: 'freshfone_'+ call.getCallSid()
      };
      this.notification = new Notification(title,notificationProperties);
      this.notification.onclick = function(args) { window.focus(); this.close ();};
    }

  };
}(jQuery));