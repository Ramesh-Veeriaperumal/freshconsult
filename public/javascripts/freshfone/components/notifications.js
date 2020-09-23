var FreshfoneNotification;
(function($) {
	"use strict"
	var incomingConnections = {},
		ongoingNotifications = {},
		onholdNotifications = [],
		MAX_PARALLEL_NOTIFICATIONS = 3;

	FreshfoneNotification = function () {
		this.init();
		this.originalJsonStringify = JSON.stringify;
		this.isChrome = ($.browser.webkit && navigator.userAgent.indexOf('Chrome') >= -1);
		this.isOriginal = true;
		this.bindPjaxTitleChange();
		this.alertTitle="Incoming Call..";
		this.originalTitle = document.title;
		this.desktopNotification = false;
	};

	FreshfoneNotification.prototype = {
		init: function () { 
			this.notifyTabsFlag=false;
		},
		loadDependencies: function (freshfonecalls, freshfoneUserInfo) {
			this.freshfonecalls = freshfonecalls;
			this.freshfoneUserInfo = freshfoneUserInfo;
		},
		anyAvailableConnections: function (connection) {
			var freshfoneConnection = new FreshfoneConnection(connection, this);
			incomingConnections[connection.parameters.CallSid] = freshfoneConnection;
			if (Object.keys(ongoingNotifications).length < MAX_PARALLEL_NOTIFICATIONS) {
				this.pushOngoingNotification(freshfoneConnection);
			} else {
				this.pushOnholdNotifications(freshfoneConnection);
			}
		},

		setDirectionIncoming: function () {
			this.freshfonecalls.setDirectionIncoming();
		},

		closeConnections: function (connection) {
			if (ongoingNotifications[connection.parameters.CallSid]) {
				this.popOngoingNotification(connection);
			} else {
				var freshfoneConnection = incomingConnections[connection.parameters.CallSid];
				this.deleteOnholdNotifications(freshfoneConnection);
			}
		},

		pushOngoingNotification: function (freshfoneConnection) {
			var self = this;
			ongoingNotifications[freshfoneConnection.callSid()] = freshfoneConnection;
			if (!this.notifyTabsFlag) {
				this.notifyTabs();
				this.bindResetTitle();
			}
			freshfoneConnection.createNotification();
		},

		popOngoingNotification: function (connection, freshfoneConnection) {
			this.deleteNotification(connection, freshfoneConnection);
			delete ongoingNotifications[connection.parameters.CallSid];
			this.popOnholdNotifications();
			if (!Object.keys(ongoingNotifications).length) { this.resetTitle(); }
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

		popAllNotification: function (acceptedConnection) {
			this.removeAllOnholdNotifications(acceptedConnection);
			this.removeAllOngoingNotifications(acceptedConnection);
			this.resetTitle();
		},

		removeFromOnholdNotifications: function (freshfoneConnection) {
			var index = onholdNotifications.indexOf(freshfoneConnection);
			if (~index) { onholdNotifications.splice(index, 1); }
			this.deleteNotification(freshfoneConnection.connection, freshfoneConnection);
		},

		removeAllOnholdNotifications: function (acceptedConnection) {
			var self = this;
			$.each(onholdNotifications, function (i, freshfoneConnection) {
				self.deleteNotification(freshfoneConnection.connection, freshfoneConnection);
				if (acceptedConnection !== freshfoneConnection.connection) { freshfoneConnection.reject(); }
			});
			onholdNotifications = [];
		},

		removeAllOngoingNotifications: function (acceptedConnection) {
			var self = this;
			$.each(ongoingNotifications, function (callSid, freshfoneConnection) {
				self.deleteNotification(freshfoneConnection.connection, freshfoneConnection);
				if (acceptedConnection !== freshfoneConnection.connection) { freshfoneConnection.reject(); }
			});
			ongoingNotifications = {};
		},

		deleteNotification: function (connection, freshfoneConnection) {
			freshfoneConnection = freshfoneConnection || ongoingNotifications[connection.parameters.CallSid];
			freshfoneConnection.deleteObject();
		},

		jsonFix: function () {
			var self = this;
			if (!this.isChrome) { return false; }
			JSON.stringify = function (value) {
				var array_tojson = Array.prototype.toJSON, r;
				delete Array.prototype.toJSON;
				r = self.originalJsonStringify(value);
				Array.prototype.toJSON = array_tojson;
				return r;
			};
		},

		resetJsonFix: function () {
			if (this.isChrome) { JSON.stringify = this.originalJsonStringify; }
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
			$(document).on('mouseenter.freshfone mouseleave.freshfone', function () {
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
			$(document).off('mouseenter.freshfone mouseleave.freshfone');
			self.notifyTabsFlag=false;
		},

		initializeCall: function (connection) {
			var freshfoneConnection = incomingConnections[connection.parameters.CallSid];
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
		
		getIncomingConnection: function (CallSid) {
			return incomingConnections[CallSid];
		},
		setTransferMeta: function (type, agent){
			this.freshfoneUserInfo.setTransferMeta(type, agent);
		}
};

}(jQuery));