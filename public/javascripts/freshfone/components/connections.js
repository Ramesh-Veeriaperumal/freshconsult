var FreshfoneConnection;
(function ($) {
	"use strict";

	FreshfoneConnection = function (connection, freshfoneNotification) {
		this.init();
		this.connection = connection;
		this.freshfoneNotification = freshfoneNotification;
	};
	FreshfoneConnection.prototype = {
		init: function () {
		},
		createNotification: function () {
			var self = this;
			var $incomingCallWidget = $('#incomingWidget').clone().tmpl();
			$incomingCallWidget.attr('id', this.callSid());

			$incomingCallWidget.prependTo('#freshfone_notification_container');
			this.$userInfoContainer = $('#freshfone_notification_container').find('#' + this.callSid());
			this.setCustomerNumber();
			this.freshfoneNotification.setRequestObject(this);
			this.freshfoneNotification.prefillContactTemplate(this.customerNumber);
			this.bindEventHandlers();
			freshfoneNotification.userInfo(this.customerNumber, this);
		},
		bindEventHandlers: function () {
			var self = this;
			this.$userInfoContainer.one('click','#reject_call', function () {
				self.reject();
			});
			this.$userInfoContainer.one('click','#accept_call', function () {
				$("#accept_call").text("Accepting...");
				self.$userInfoContainer.off('click','#reject_call');
				self.accept();
			});
		},
		accept: function () {
			this.freshfoneNotification.jsonFix();
			this.canAcceptCall();
		},
		reject: function () {
			$("#log").text("Ready");
			ffLogger.log({'action': "Rejected by agent", 'params': this.connection.parameters});
			this.connection.reject();
			this.freshfoneNotification.popOngoingNotification(this.connection, this);
		},
		callSid: function() {
			return this.connection.parameters.CallSid;
		},
		setCustomerNumber: function () {
			this.customerNumber = this.connection.parameters.From;
		},
		deleteObject: function () {
			var self = this;
			if (this.$userInfoContainer) {
				this.$userInfoContainer.hide('fast', function () {
					self.$userInfoContainer.remove();
					self.$userInfoContainer = null;
				});
			}
			if(this.notification) {
				this.notification.closeWebNotification();
			}
		},
		canAcceptCall: function () {
			var self = this;
			$.ajax({
				type: 'GET',
				dataType: "json",
				url: '/freshfone/call/inspect_call',
				data: { "call_sid": this.callSid() },
				success: function (data) { 
					if(data.can_accept) {
						self.freshfoneNotification.setDirectionIncoming();
						self.connection.accept();
					}else{
						self.reject();
					}
				},
				error: function () {
					ffLogger.logIssue("Unable accept the incoming call for "+ CURRENT_USER.id, { "params" : data });
				 }
			});
		},
		createDesktopNotification: function () {
			if ( this.canCreateDesktopNotification() ) {
				try {
					this.notification = new FreshfoneDesktopNotification(this);
				}
				catch (e) {
					console.log(e);
				}
			}
		},
		incomingAlert: function () {
			var self = this;
			var key = self.connection.parameters.CallSid + ":sound";
			if($.cookie(key)){
        self.connection.device.soundcache.stop("incoming");
        freshfoneNotification.desktopNotification = false;
      } else {
      	freshfoneNotification.desktopNotification = true;
      }
      var expire = new Date();
      expire.setTime(expire.getTime() + (10 * 1000));
      $.cookie(key, true, {path:'/', expires: expire});
		},
		canCreateDesktopNotification: function () {
			return (freshfonewidget.isSupportWebNotification() 
				&& freshfoneNotification.desktopNotification );
		}
	};
}(jQuery));