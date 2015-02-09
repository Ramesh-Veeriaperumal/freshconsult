var FreshfoneUser,
	userStatus = { OFFLINE : 0, ONLINE : 1, BUSY : 2};
	userStatusReverse = { 0 : 'OFFLINE', 1: 'ONLINE', 2: 'BUSY'};

(function ($) {
    "use strict";
		var socket_init_params;
	FreshfoneUser = function () {
		this.setStatus(freshfone.current_status);
		this.online = (this.status === userStatus.ONLINE);
		this.availableOnPhone = freshfone.available_on_phone;
		this.cached = {};
		this.newTokenGenerated = false;
		if (this.online) { this.updateUserPresence(); }
		if (!freshfone.user_phone) { this.toggleAvailabilityOnPhone(true); }
	};



	FreshfoneUser.prototype = {
		init: function () {
			// this.status = null;
		},
		$availableOnPhone: $('.freshfone_widget .availabilityOnPhone'),
		$userPresence: $("#freshfone-presence-toggle"),
		$userPresenceImage: function () {
			return this.cached.$userPresenceImage = this.cached.$userPresenceImage ||
																							this.$userPresence.find("img");
		},
		loadDependencies: function (freshfonecalls,freshfonesocket,freshfoneNotification) {
			this.freshfonesocket = freshfonesocket;
			this.freshfonecalls = freshfonecalls;
			this.freshfonesocket.init(this);
			this.freshfoneNotification = freshfoneNotification;
		},
		isOnline : function () {
			return this.status === userStatus.ONLINE;
		},
		isBusy : function(){
			return this.status === userStatus.BUSY;
		},
		toggleUserPresence: function () {
			if(this.online  && this.freshfoneNotification.canAllowUserPresenceChange()) {
				return;
			}
			this.online = !this.online;
			if (!this.updateUserPresence()) { this.online = !this.online; }
		},
		updateUserPresence: function () {
			if (this.status === userStatus.BUSY) { this.setPresence(this.status, this.$userPresenceImage()); return false; }
			
			var status = (this.online ? userStatus.ONLINE : userStatus.OFFLINE);
			
			this.setPresence(status, this.$userPresenceImage());

			return true;
		},
		userPresenceDomChanges: function () {
			switch (this.status) {
				case 0 :
					this.offlineUserPresenceDomChanges(); break;
				case 1 :
					this.onlineUserPresenceDomChanges(); break;
				case 2 :
					this.busyUserPresenceDomChanges(); break;
				default :
					ffLogger.logIssue("Unexpected error in setting user presence");
			}
		},
		get_presence: function(callback) {
			$.ajax({
        url : '/freshfone/users/get_presence',
        type: 'GET',
        success: function(json) {
        	if (callback) callback(null, json.status);
        },
        error: function(e) {
        	if (callback) callback(e, null);
        }
			});
		},
		reset_presence_on_reconnect: function () {
			$.ajax({
				type: "POST",
				url: "/freshfone/users/reset_presence_on_reconnect"
			});
		},
		onlineUserPresenceDomChanges: function () {
			this.$userPresenceImage()
				.addClass('header-icons-agent-ffone-on')
				.removeClass('header-icons-agent-ffone-off')
				.removeClass('header-icons-agent-ffone-busy');
			this.$userPresence.attr('title', freshfone.freshfone_user_online_text);
		},

		offlineUserPresenceDomChanges: function () {
			this.$userPresenceImage()
				.addClass('header-icons-agent-ffone-off')
				.removeClass('header-icons-agent-ffone-on')
				.removeClass('header-icons-agent-ffone-busy');
			this.$userPresence.attr('title', freshfone.freshfone_user_offline_text);
		},

		busyUserPresenceDomChanges: function () {
			this.$userPresenceImage()
				.addClass('header-icons-agent-ffone-busy')
				.removeClass('header-icons-agent-ffone-on')
				.removeClass('header-icons-agent-ffone-off');
			this.$userPresence.attr('title', freshfone.freshfone_user_busy_text);
		},
		
		setPresence: function (status, $loading_element) {
			this.setStatus(status);
			$("#log").text("Registering Freshfone Client...");

			// this.handleFreshfoneSocket();
			this.getCapabilityToken($loading_element);
		},
		
		handleFreshfoneSocket: function () {
			var isDashboard = $('.freshfone_dashboard').length !== 0; //Temp SuperDirtyUgly Fix..
			if (this.status === userStatus.OFFLINE) {
				this.freshfonesocket.disconnect();
			} else if (this.status === userStatus.ONLINE) {
				// socket ip
				this.freshfonesocket.connect();
				this.freshfonesocket.registerCallbacks();
			}
		},
		
		toggleAvailabilityOnPhone: function (skip_alert) {
			if (freshfone.user_phone) {
				if (this.availableOnPhone || isValidNumber(freshfone.user_phone)) {
					this.availableOnPhone = !this.availableOnPhone;
					this.publishAvailabilityOnPhone();	
				} else {
					if(!skip_alert) { alert(freshfone.invalid_user_number_text); }
					this.toggleAvailabilityOnPhoneClass();
				}
			} else {
				this.availableOnPhone = false;
				this.toggleAvailabilityOnPhoneClass();
				if (!skip_alert) { alert(freshfone.forward_number_alert); }
			}
		},
		
		toggleAvailabilityOnPhoneClass: function () {
			var msg = this.availableOnPhone ? freshfone.available_on_phone_text :
																				freshfone.available_on_browser_text;
			this.$availableOnPhone.toggleClass('active', this.availableOnPhone);
			this.$availableOnPhone.attr('title', msg);
		},

		publishAvailabilityOnPhone: function () {
			var self = this;
			$.ajax({
				type: 'POST',
				dataType: "json",
				url: '/freshfone/users/availability_on_phone',
				data: { "available_on_phone": (this.availableOnPhone || false) },
				success: function (data) {
					if (data.update_status) {
						self.toggleAvailabilityOnPhoneClass();
					} else {
						self.availableOnPhone = !self.availableOnPhone;
					}
				},
				error: function (data) { self.availableOnPhone = !self.availableOnPhone; }
			});
		},

		getCapabilityToken: function ($loading_element, force_generate) {
			/* Create the Client with a Capability Token */
			var self = this;
			if (this.busyRepress()) return;
			this.newTokenGenerated = true;
			if ($loading_element) { $loading_element.addClass('header-spinner'); }
			var params = { "status": this.status }
			if (force_generate) { params["force"] = true };
			$.ajax({
				type: 'POST',
				dataType: "json",
				url: '/freshfone/users/refresh_token',
				data: params,
				success: function (data) {
					if ($loading_element) { $loading_element.removeClass('header-spinner'); }
					if (data.update_status) {
						self.storeNewToken(data);
						self.userPresenceDomChanges();
					} else {
						self.status = self.previous_status;
					}
				},
				error: function (data) {
					self.status = self.previous_status;
					if ($loading_element) { $loading_element.removeClass('header-spinner'); }
					ffLogger.logIssue("Unable get Capability Token for "+ CURRENT_USER.id, { "data" : data });
				}
			});
		},

		busyRepress: function() {
			if (this.status != userStatus.BUSY) return false;
			else if ((typeof this.lastRequested == 'undefined') || (new Date() - this.lastRequested >= 30000)) {
				this.lastRequested = new Date();
				return false;
			};
			ffLogger.logIssue("Repressing refresh_token for "+ CURRENT_USER.id + " because of repeated requests while busy");
			return true;
		},

		updatePresence: function (async) {
			if (async === undefined) { async = true };
			$.ajax({
				type: "POST",
				url: "/freshfone/users/presence",
        dataType: "json",
				async: async,
				data: { "status": this.status }
			});
		},

		storeNewToken: function (data) {
			setCookie("freshfone", data.token, 1);
			this.setupDevice();
		},

		setupDevice: function (token) {
			var CapabilityToken = token || getCookie('freshfone');
			try {
				Twilio.Device.setup(CapabilityToken);
				ffLogger.logIssue("Freshfone Device Config", {
					"Capabilitytoken" : CapabilityToken, "Time Stamp": Date().toString()
				});
			} catch (e) {
				ffLogger.logIssue("Freshfone Device Config Failure", {
					"Capabilitytoken" : CapabilityToken, "Time Stamp": Date().toString()
				});
			}
		},

		initializeDevice: function () {
			getCookie('freshfone') === undefined ? this.getCapabilityToken() : this.setupDevice();
		},

		setStatus: function (status, init_value) {
			this.previous_status = init_value || this.status;
			this.status = parseInt(status, 10);
		},
		
		resetStatusAfterCall: function () {
			var status = (this.online ? userStatus.ONLINE : userStatus.OFFLINE);
			this.setStatus(status);
		},

		bridgeQueuedCalls: function () {
			if (!this.online) { return false; }
			$.ajax({
				url: '/freshfone/queue/bridge',
				type: 'POST',
				success: function (data) {  }
			});
		},

		publishLiveCall: function (dontUpdateCallCount) {
			var self = this;
			self.setStatus(userStatus.BUSY);
			$.ajax({
				type: 'POST',
        dataType: "json",
				url: '/freshfone/users/in_call',
				data: { 'From': this.freshfonecalls.tConn.parameters.From,
								'To': this.freshfonecalls.tConn.parameters.To,
								'CallSid': this.freshfonecalls.getCallSid(),
								'outgoing': this.freshfonecalls.isOutgoing(),
								'dont_update_call_count' : dontUpdateCallCount },
				success: function (data) {
					if (!data.update_status) {
						self.status = self.previous_status;
					} else {
						self.freshfonecalls.setCallSid(data.call_sid); 
					} 
					ffLogger.log({'action': "Getting CallSid from in_Call ajax", 'params': data});
				},
				error: function (data) { 
					self.status = self.previous_status; 
					ffLogger.logIssue("Call Publish Failure", { "data" : data });
				}
			});
		}
	};
	
}(jQuery));
