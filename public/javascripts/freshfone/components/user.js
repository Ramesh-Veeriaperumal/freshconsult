var FreshfoneUser,
	userStatus = { OFFLINE : 0, ONLINE : 1, BUSY : 2, ACW : 3};
	userStatusReverse = { 0 : 'OFFLINE', 1: 'ONLINE', 2: 'BUSY', 3: 'ACW'};

(function ($) {
    "use strict";
		var socket_init_params;
	FreshfoneUser = function () {
		this.setStatus(this.getInitialState());
		this.online = (this.status === userStatus.ONLINE);
		this.availableOnPhone = freshfone.available_on_phone;
		this.cached = {};
		this.newTokenGenerated = false;
		this.tokenRegenerationOn = null;
		if (freshfone.isActiveOrTrial && !this.isOffline()) { this.updateUserPresence(); }
		if (this.canResetPhoneAvailabilityOnReload()){ 
			//reset availability back to browser/app if agent is available on phone and deletes number from profile settings.
			this.toggleAvailabilityOnPhone(true);
		}
		this.bindUserPresenceHover();
		if(this.chromeSSLRestriction()){
			//From "47.0.2526.80" Chrome version, SSL is mandated. So, giving alerts temporarily
			this.bindSSLAlert();
		}
	};



	FreshfoneUser.prototype = {
		init: function () {
			// this.status = null;
		},
		$userPresence: $("#freshfone-presence-toggle"),
		$preferenceMessage: $('.freshfone-preference-tooltip'),
		$availableOnPhone: $('.ff_presence_options #availableOnPhone'),
		$availableOnBrowser: $('.ff_presence_options #availableOnBrowser'),
		$onlineAvailabilityText: $('.ff_presence_options .ff_available .online_availability_text'),
		$acwAvailabilityText: $('.ff_presence_options .ff_available .acw_availability_text'),
		$availabilityOptions: $("#FreshfonePresenceOptions"),
		$userPresenceImage: function () {
			return this.cached.$userPresenceImage = this.cached.$userPresenceImage ||
																							this.$userPresence.find("i");
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
		isOffline : function(){
			return this.status === userStatus.OFFLINE;
		},
		isBusy : function(){
			return this.status === userStatus.BUSY;
		},
		isAcw : function(){
			return this.status === userStatus.ACW;
		},
		toggleUserPresence: function () {
			if(!freshfone.isActiveOrTrial)
				return;

			if(this.online  && this.freshfoneNotification.canAllowUserPresenceChange()) {
				return;
			}
			if(this.isBusy()){
				this.setPresence(freshfone.current_preference, this.$userPresenceImage());
				return;
			}
			this.online = !this.online;
			var status = (this.isOffline() ? userStatus.ONLINE : userStatus.OFFLINE);
			this.setPresence(status, this.$userPresenceImage());
		},
		updateUserPresence: function () {
			if (this.isBusyOrAcw()){
				this.setPresence(this.status, this.$userPresenceImage()); return false;
			}
			
			var status = (this.online ? userStatus.ONLINE : userStatus.OFFLINE);
			
			this.setPresence(status, this.$userPresenceImage());

			return true;
		},
		userPresenceDomChanges: function (isOnPhone, fromSocket) {
			if(fromSocket){
				isOnPhone = (isOnPhone == 'true');
				this.availableOnPhone = isOnPhone;
			}
			var availableOnPhone = isOnPhone ||  this.availableOnPhone;
			switch (this.status) {
				case 0 :
					this.offlineUserPresenceDomChanges(); break;
				case 1 :
					this.onlineUserPresenceDomChanges(availableOnPhone); break;
				case 2 :
					this.busyUserPresenceDomChanges(availableOnPhone); break;
				case 3 :
					this.acwUserPresenceDomChanges(availableOnPhone); break;
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

		onlineUserPresenceDomChanges: function (available_on_phone) {
			var presenceClass = available_on_phone ? "ficon-ff-via-phone" : "ficon-ff-via-browser";
			this.cleanUpUserPresenceDomClass();
			this.toggleAvailabilityText(true);
			this.$userPresenceImage().addClass(presenceClass);
			this.$preferenceMessage.attr('title', freshfone.freshfone_user_online_text);
			this.updateAvailabilityOptionTemplate(available_on_phone);
		},

		offlineUserPresenceDomChanges: function () {
			this.cleanUpUserPresenceDomClass();
			this.$userPresenceImage().addClass('ficon-phone-disable');
			this.$preferenceMessage.attr('title', freshfone.freshfone_user_offline_text);
		},

		busyUserPresenceDomChanges: function (available_on_phone) {
			this.userPresenceImageChanges(available_on_phone);
			this.$userPresenceImage().addClass('ff-busy');
			this.$preferenceMessage.attr('title', freshfone.freshfone_user_busy_text);
		},
		acwUserPresenceDomChanges: function (available_on_phone) {
			this.userPresenceImageChanges(available_on_phone);
			this.$userPresenceImage().addClass('ff-acw');
			this.$preferenceMessage.attr('title', freshfone.freshfone_user_in_acw_text);
			this.$availabilityOptions.find(".ticksymbol").remove();
			this.toggleAvailabilityText(false);
			this.$availableOnPhone.removeClass('active');
			this.$availableOnBrowser.removeClass('active');
		},
		cleanUpUserPresenceDomClass: function () {
			this.$userPresenceImage()
			.removeClass('ficon-phone-disable ficon-ff-via-phone ficon-ff-via-browser ff-busy ff-acw header-spinner');
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
		
		toggleAvailabilityOnPhone: function (skipAlert) {
			if (freshfone.user_phone) {
				this.availableOnPhone = !this.availableOnPhone;
				this.publishAvailabilityOnPhone();	
			} else {
				//added availableOnPhone check to handle click in acw-state as both the options will be clickable
				//but alert-message should be displayed only when "via Phone" option is clicked.
				if (!skipAlert && !this.availableOnPhone){
					alert(freshfone.forward_number_alert);
				}
				this.availableOnPhone = false;
				this.publishAvailabilityOnPhone();
			}
		},
		
		toggleAvailabilityOnPhoneClass: function () {
			var msg = this.availableOnPhone ? freshfone.available_on_phone_text :
																				freshfone.available_on_browser_text;
			this.$availableOnPhone.toggleClass('active', this.availableOnPhone);
			this.$availableOnBrowser.toggleClass('active', !this.availableOnPhone);
			this.userPresenceDomChanges(this.availableOnPhone);
		},

		publishAvailabilityOnPhone: function () {
			this.cleanUpUserPresenceDomClass()
			this.$userPresenceImage().addClass('header-spinner'); 
			var self = this;
			if(self.isAcw()){ self.setStatus(userStatus.ONLINE) };
			$.ajax({
				type: 'POST',
				dataType: "json",
				url: '/freshfone/users/availability_on_phone',
				data: { "available_on_phone": (this.availableOnPhone || false) },
				success: function (data) {
					if (!data.update_status) {
						self.availableOnPhone = !self.availableOnPhone;
						if(data.invalid_number){
							alert(freshfone.invalid_user_number_text);
						}
					}
					self.$userPresenceImage().removeClass('header-spinner'); 
					self.toggleAvailabilityOnPhoneClass();
				},
				error: function (data) { self.availableOnPhone = !self.availableOnPhone; 
					self.$userPresenceImage().removeClass('header-spinner');
					if(data.status != 403)
						self.toggleAvailabilityOnPhoneClass();
				}
			});
		},

		getCapabilityToken: function ($loading_element, force_generate) {
			/* Create the Client with a Capability Token */
			var self = this;
			if (this.busyRepress()) return;
			this.newTokenGenerated = true;
			if ($loading_element) { 
				this.cleanUpUserPresenceDomClass();
				$loading_element.addClass('header-spinner'); 
			}
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
						self.userPresenceDomChanges(data.availability_on_phone);
					} else {
						self.status = self.previous_status;
						self.userPresenceDomChanges();
					}
				},
				error: function (data) {
					self.status = self.previous_status;
					if ($loading_element) { $loading_element.removeClass('header-spinner'); }
					ffLogger.logIssue("Unable get Capability Token for "+ freshfone.current_user_details.id, { "data" : data });
				}
			});
		},

		busyRepress: function() {
			if (this.status != userStatus.BUSY) return false;
			else if ((typeof this.lastRequested == 'undefined') || (new Date() - this.lastRequested >= 30000)) {
				this.lastRequested = new Date();
				return false;
			};
			ffLogger.logIssue("Repressing refresh_token for "+ freshfone.current_user_details.id + " because of repeated requests while busy");
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
				Twilio.Device.setup(CapabilityToken, { debug: freshfone.isDebuggingMode });
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
			if (getCookie('freshfone') === undefined){
				this.getCapabilityToken();
			}
			else 
				this.setupDevice();
		},

		setStatus: function (status, init_value) {
			this.previous_status = init_value || this.status;
			this.status = parseInt(status, 10);
		},

		manageAvailabilityToggle: function(status){
			var flag = this.isBusyOrOffline(status) ? 'disable' : 'enable';
			$("a[rel=ff-hover-popover]").popover(flag);
		},

		isBusyOrOffline: function(status){
			return ((status == userStatus.BUSY) || (status == userStatus.OFFLINE));
		},

		isOnlineOrOffline: function(){
			return [userStatus.ONLINE, userStatus.OFFLINE].includes(this.status);
		},

		isBusyOrAcw: function(){
			return [userStatus.BUSY, userStatus.ACW].includes(this.status);
		},
		
		resetStatusAfterCall: function () {
			var status = (this.online ? userStatus.ONLINE : userStatus.OFFLINE);
			this.setStatus(status);
		},

		publishLiveCall: function (dontUpdateCallCount) {
			var self = this;
			self.setStatus(userStatus.BUSY);
			if(freshfone.isTrial)
				freshfoneSubscription.hideTrialWarnings();
			$.ajax({
				type: 'POST',
        dataType: "json",
				url: '/freshfone/users/in_call',
				data: { 'From': this.freshfonecalls.tConn.parameters.From,
								'To': this.freshfonecalls.tConn.parameters.To,
								'CallSid': this.freshfonecalls.tConn.parameters.CallSid,
								'outgoing': this.freshfonecalls.isOutgoing(),
								'dont_update_call_count' : dontUpdateCallCount },
				success: function (data) {
					if (!data.update_status) {
						self.status = self.previous_status;
					} else {
						self.freshfonecalls.setCallSid(data.call_sid); 
						self.freshfonecalls.registerCall(data.call_sid); //used in conference. can be merged with above and used for both conf and non conf users
						self.freshfonecalls.setCallId(data.call_id);
						if(freshfone.isTrial)
							freshfoneSubscription.loadWarningsTimer();
					} 
					ffLogger.log({'action': "Getting CallSid from in_Call ajax", 'params': data});
				},
				error: function (data) { 
					self.status = self.previous_status; 
					ffLogger.logIssue("Call Publish Failure", { "data" : data });
				}
			});
		},
		makeOffline: function (){
			if(this.online){
				this.setStatus(userStatus.OFFLINE);
				this.online = !this.online;
			}
		},
		bindUserPresenceHover: function () {
			var self = this;
			$('body').on('click', '.ff_presence_options .availabilityOnPhone', function(){
				var	to_phone = $(this).data('to_phone');
				self.updateAvailability(to_phone, this);
			});
			if(freshfone.isTrial) { return; }
			$("a[rel=ff-hover-popover]").livequery(function(){
				$(this).popover({ 
				  delayOut: 300,
				  trigger: 'manual',
				  offset: 0,
				  reloadContent: true,
				  html: true,
				  placement: 'below',
				  template: '<div class="dbl_left arrow"></div><div class="ff_hover_card inner"><div class="content ff_presence_options"><div></div></div></div>',
				  content: function(){
				    return self.$availabilityOptions.html();
				  }
				}); 
			});
			this.updateAvailabilityOptionTemplate(this.availableOnPhone);
		},
		updateAvailabilityOptionTemplate: function(availableOnPhone){
			var elementId= availableOnPhone ? "availableOnPhone" :  "availableOnBrowser";
			this.$availabilityOptions.find(".ticksymbol").remove();
			$(this.$availabilityOptions.find("#"+elementId)).prepend($('<span class="icon ticksymbol"></span>'));
		},
		updateAvailability: function(toPhone, element){
			this.handleAcwAvailabilityToggle(toPhone);
			if(this.availableOnPhone == toPhone) {return;}
			if(!freshfone.isTrial)
				this.toggleAvailabilityOnPhone(false);
			this.updateAvailabilityDomChange(element);
		},
		updateAvailabilityDomChange: function (element) {
			if($(element).data('to_phone') === this.availableOnPhone) {
				$(element).parent().find('.ticksymbol').remove();
	      $(element).prepend($('<span class="icon ticksymbol"></span>'));
	      this.updateAvailabilityOptionTemplate($(element).attr('id'));
	    }
		},
		bindSSLAlert: function(){
			$('.browser_alert').show();
			$("a[rel=ff-alert-popover]").livequery(function(){
				$(this).popover({ 
				  trigger: 'manual',
				  offset: 0,
				  html: true,
				  template: $("#alert_message").html()
				}); 
			});
		},
		chromeSSLRestriction: function(){
			if (window.chrome && window.location.protocol === "http:" && this.validateEnvironment()) {
				var version = $.browser.version.split(".");	
		  	var stable = parseInt(version[0]);
		  	var patch = parseInt(version[2]);
				if(stable > 47 || (stable == 47 && patch >= 2526)){
					return true;
				}
				return false;
			}
		},
		validateEnvironment: function(){
			return freshfone.env != "development"
		},
		handleAcwAvailabilityToggle: function(isOnPhone){
			if(this.isAcw() && (this.availableOnPhone == isOnPhone)){
				this.availableOnPhone = !this.availableOnPhone;
			}
		},
		userPresenceImageChanges: function(available_on_phone){
			var presenceClass = available_on_phone ? "ficon-ff-via-phone" : "ficon-ff-via-browser";
			this.$userPresenceImage().addClass(presenceClass);
		},
		//To handle the case where agent is logging in from offline state. Then return
		//current incoming-preference instead of returning offline.
		getInitialState: function(){
			if(freshfone.current_status == userStatus.OFFLINE){
				return freshfone.current_preference;
			}
			else{
				return freshfone.current_status;
			}
		},
		toggleAvailabilityText: function(show){
			this.$onlineAvailabilityText.toggle(show);
			this.$acwAvailabilityText.toggle(!show);
		},
		canResetPhoneAvailabilityOnReload: function(){
			return (!freshfone.user_phone && !freshfone.isTrial && freshfone.isActiveOrTrial && this.availableOnPhone && !this.isAcw());
		}
	};
}(jQuery));
