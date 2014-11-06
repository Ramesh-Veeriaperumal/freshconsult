var FreshfoneDesktopNotification;
(function($) {
  "use strict";
  FreshfoneDesktopNotification = function (freshfoneConnection) {
    this.callConnection = freshfoneConnection
    this.init();
  };
  FreshfoneDesktopNotification.prototype = {
    init: function () {
      this.createWebNotification();
    },
    createWebNotification: function () {
      var title,notificationProperties, bodyText, callMeta;
      if(Notification.permission == 'default') { 
        this.bindDeskNotifierButton();
      }
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
    }
  };
}(jQuery));