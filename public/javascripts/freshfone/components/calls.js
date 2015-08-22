var FreshfoneCalls,
callStatusReverse = { 0: "NONE", 1: "INCOMINGINIT", 2: "OUTGOINGINIT", 3: "ACTIVECALL", 4: "AVAILABLE" };
(function ($) {
    "use strict";
	var callDirection = { NONE : 0, INCOMING : 1, OUTGOING : 2 },
		callStatus = { NONE: 0, INCOMINGINIT : 1, OUTGOINGINIT : 2, ACTIVECALL : 3, AVAILABLE : 4 },
		TRANSFER_FALLBACK_STATUS = ["ignored", "noAnswer"],
		TRANSFERING_STATUS = ["inProgress", "connected"],
		numbersHash = freshfone.numbersHash,
		phoneNumber;
	FreshfoneCalls = function () {
		this.init();
		this.currentUser = freshfone.current_user;
		this.ALLOWED_DIGITS = 50;
		this.cached = {};
		this.freshfoneCallTransfer = {};
		this.exceptionalNumber=false;
		this.recentCaller = 0;
		this.callInitiationTime = null;
	};

	FreshfoneCalls.prototype = {
		init: function () {
			this.tConn = false;
			this.isMute = 0;
			this.isHold = 0;
			this.conferenceMode = false;
			this.conferenceConn = false;
			this.status = callStatus.NONE;
			this.direction = callDirection.NONE;
			this.callerId = null;
			this.callerName = null;
			this.callSid = null;
			this.number = "";
			this.error = null;
			this.errorcode = null;
			this.transfered = false;
			this.transferSuccess = false;
			this.recordingInstance = null;
			this.group_id = null;
			this.resetCallTransferTimer();
		},
		resetFlags: function() {
			this.errorcode = null;
			this.lastAction = null;
			this.transfered = false;
			this.isHold = 0;
		},
		initGroup: function (group_id){
			this.group_id = group_id
		},
		$container: $('.freshfone_content_container'),
		loadDependencies: function (freshfoneuser, timer, freshfoneUserInfo) {
			this.freshfoneuser = freshfoneuser;
			this.freshfoneUserInfo = freshfoneUserInfo;
			this.timer = timer;
		},
		$invalidNumberText: function () {
			return this.cached.$invalidNumberText = this.cached.$invalidNumberText ||
																							this.$container.find('.invalid_phone_text');
		},
		$invalidPhoneNumber: function () {
			return this.cached.$invalidPhoneNumber = this.cached.$invalidPhoneNumber ||
																							this.$container.find('.invalid_phone_num');
		},
		$alreadyInCallText: function () {
			return this.cached.$alreadyInCallText = this.cached.$alreadyInCallText ||
																							this.$container.find('.already_in_call_text');
		},
		$infoText: function () {
			return this.cached.$infoText = this.cached.$infoText ||
																			this.$container.find('.info_message');
		},
		$restrictedCountryText: function () {
			return this.cached.$restrictedCountryText = this.cached.$restrictedCountryText ||
																			this.$container.find('.restricted_country');
		},
		$strangeNumberText: function() {
			return this.cached.$strangeNumberText = this.cached.$strangeNumberText || this.$container.find('.strange_number');
		},
		$outgoingNumberSelector: function () {
			return this.cached.$outgoingNumber = this.cached.$outgoingNumber ||
																			this.$container.find('#outgoing_number_selector');
		},
		
		outgoingNumberId: function () {
			return (this.$outgoingNumberSelector().val() || 
							this.$outgoingNumberSelector().data('number_id'));
		},

		outgoingNumber: function () { return numbersHash[this.outgoingNumberId()]; },

		$dialpadButton: $('.freshfone_widget .showDialpad'),
		$number: $("#number"),
//		isKeyPressAllowed: function (char) {
//			return ((char >= 48 && char <= 57) || ($.inArray(char, [35, 42, 43]) >= 0)) &&
//			($('#number').val().length < this.ALLOWED_DIGITS);
//		},

		isMaxSizeReached: function () {
			return (this.$number.val().length > this.ALLOWED_DIGITS);
		},

		// removeDisallowedCharacters: function () {
		//	var numpad = $('#number');
		//	numpad.val(numpad.val().replace(/[^\d\+\*\#]/g, '')
		//                              .substring(0, this.ALLOWED_DIGITS));
		// },
		removeExtraCharacters: function () {
			var numpad = this.$number;
			numpad.val(numpad.val().substring(0, this.ALLOWED_DIGITS));
		},
		isOutgoing: function () {
			return (this.direction === callDirection.OUTGOING);
		},
		setDirectionIncoming: function () {
			this.direction = callDirection.INCOMING;
			this.status = callStatus.ACTIVECALL;
		},
		setDirectionOutgoing: function () {
			this.direction = callDirection.OUTGOING;
			this.status = callStatus.ACTIVECALL;
		},
		getCallSid: function () {
			var callSid = this.call || this.callSid 
			if(callSid == undefined && this.tConn.parameters && this.tConn.parameters.CallSid){
				callSid = this.tConn.parameters.CallSid;
			}
			return callSid;
		},
		setCallSid: function (call_sid) {
			this.callSid = call_sid;
		},
		fetchCallerDetails: function (details) {
			this.callerId = details.callerId;
			this.callerName = details.callerName;
			this.number = details.number;
		},
		formattedNumber : function () {
			return formatInternational(this.callerLocation(), this.number);
		},
		callerLocation: function () {
			return countryForE164Number(this.number);
		},
		recordMessage: function (messageSelector, numberId) {
			this.recordingInstance = messageSelector;
			if(!this.call_validation(false)) {
				return false;
			}
			var self = this;
			this.setDirectionOutgoing();
			var params = { record: true, number_id: numberId, agent: this.currentUser, type: "record" };
			this.actionsCall(function () { Twilio.Device.connect(params); } );
		},
		resetRecordingState: function () {
			if(this.recordingInstance) {
				this.recordingInstance.resetRecordingState();
			}
		},
		setRecordingState: function () {
			if(this.recordingInstance) {
				this.recordingInstance.setRecordingState();
			}
		},
		fetchRecordedUrl: function () {
			if(this.recordingInstance) {
				this.recordingInstance.fetchRecordedUrl();
			}
		},
		call_validation: function(isOutgoing) {
			var balance_available = true,country_enabled = true;
			$.ajax({
	   				url: '/freshfone/dial_check',
	   				dataType: "json",
	   				data: { phone_number: this.number, is_country: isOutgoing},
	   				async:false,
	   				success: function (outcome) {
							if(outcome.code == 1001){
								balance_available = false;  
							}else if(outcome.code == 1002){
								country_enabled = false;
							}
					}
			});
			if (!balance_available) { this.$infoText().show(); }
			if (!country_enabled) { this.$restrictedCountryText().show(); }  
			return (balance_available && country_enabled);
		},
		makeCall: function () {
			if (Twilio.Device.status() !== 'busy') {
				this.number = this.$number.val();
				this.makeOutgoing();
			}
		},
		makeOutgoing: function () {
			if (this.freshfoneuser.isBusy()) { return this.toggleAlreadyInCallText(true); }
			if (!this.canDialNumber()) { return this.toggleInvalidNumberText(true); }
			this.number = formatE164(this.callerLocation(), this.number);
			
			var params = { PhoneNumber : this.number, phone_country: this.callerLocation(),
										number_id: this.outgoingNumberId(), agent: this.currentUser, type: "outgoing" };

			if(!this.call_validation(true)) {
				return false;
			}
			this.actionsCall(function () { Twilio.Device.connect(params); } );
			

			this.$strangeNumberText().toggle(false);
			this.$infoText().hide();
			this.$restrictedCountryText().hide();
			this.toggleInvalidNumberText(false);
			this.toggleAlreadyInCallText(false);
			this.status = callStatus.OUTGOINGINIT;
			this.setDirectionOutgoing();
			this.freshfoneUserInfo.userInfo(this.number, true, this);
			this.disableCallButton();
		},

		toggleInvalidNumberText: function (show) {
			if (this.$alreadyInCallText().is(":visible")) { this.toggleAlreadyInCallText(false);}
			if(show && !(this.exceptionalNumberValidation(phoneNumber)) && !(freshfonewidget.checkForStrangeNumbers(phoneNumber)) ) {
			 this.$invalidNumberText().toggle(show || false);
			 this.$invalidPhoneNumber().toggle(!show || false);
			}
		},
		exceptionalNumberValidation: function(number){
			return (/[0-9]{8,15}$/.test(number) == true);
		},
		toggleAlreadyInCallText: function(show) {
			this.$alreadyInCallText().toggle(show || false);
		},
		canDialNumber: function () {	 
			if(this.number.indexOf('+') == -1){
				this.number = $.keypad.selectedCode + this.number;
   			}
			phoneNumber = this.number;
			if(freshfonewidget.checkForStrangeNumbers(this.number)){
				 this.$strangeNumberText().toggle(true);
				 return false;
			}
			return (this.number !== this.outgoingNumber()) && (isValidNumber(this.number) || this.numberValidation()) ;
		},
		numberValidation: function () {
			if(!(isValidNumber(this.number)) && this.exceptionalNumberValidation(this.number)){
   			 if (this.exceptionalNumber) {
				return true;
			 }
				this.exceptionalNumber = true;
				this.$invalidNumberText().toggle(false);
				this.$invalidPhoneNumber().toggle(true);				
		}
			return false;
		},
		hideText: function() {
			$('.invalid_phone_text').hide();
		  $('.invalid_phone_num').hide();
		  this.$restrictedCountryText().hide();
		  this.$strangeNumberText().toggle(false);
		},
		previewIvr: function (id) {
			var params = {
				preview: true,
				id: id
			};
			if(!this.call_validation(false)) {
				return false;
			}
			this.disableCallButton();
			this.setDirectionOutgoing();
			this.actionsCall(function () { Twilio.Device.connect(params); } );
			
		},
		hangup: function () {
			$("#log").text("Ready");

			Twilio.Device.disconnectAll();
			this.timer.stopCallTimer();
			this.status = callStatus.NONE;
			this.direction = callDirection.NONE;
		},
		mute: function () {
			if (this.tConn) {
				this.isMute ? this.tConn.unmute() : this.tConn.mute();
				this.isMute ^= 1;
			}
		},
		transferCall: function (id, group_id, external_number) {
			this.transfered = true;
			this.freshfoneCallTransfer = new FreshfoneCallTransfer(this, id, group_id, external_number);
		},
		isTransfering: function(){
			var status = $(".transfer-status").children(":visible").data("status");
			return ($.inArray(status, TRANSFERING_STATUS) > -1 ) ? true : false ;
    },

		dontShowEndCallForm: function () {
			if(freshfone.isConferenceMode){
				return (this.tConn.message || {}).preview || this.callError()  || this.isTransfering();
			}
			return (this.tConn.message || {}).preview || this.callError() || this.transfered;
		},

		callError: function () {
			return $.inArray(this.errorcode, [31000, 31001, 31002, 31003]) > -1;
		},
		disableCallButton: function () {
			this.callButtonDisabled = true;
			this.enableOrDisableCallButton();
		},
		enableCallButton: function () {
			this.callButtonDisabled = false;
			this.enableOrDisableCallButton();
		},
		enableOrDisableCallButton: function () {
			if (this.callButtonDisabled === true) {
				$('#number').data('keypad')._mainDiv.find('.keypad-call')
					.attr('disabled', 'disabled')
					 .text('Calling...'); 
			} else {
				$('#number').data('keypad')._mainDiv.find('.keypad-call')
					.removeAttr('disabled', 'disabled')
					 .text('Call');

			}
		},
		selectFreshfoneNumber: function (freshfone_number_id) {
			if (this.$outgoingNumberSelector().is('select') && freshfone_number_id !== undefined) {
				this.$outgoingNumberSelector().val(freshfone_number_id).trigger('change');
			}
		},
		hasUnfinishedAction : function () {
			return ($.inArray(this.errorcode, [400, 401, 31205]) > -1) && this.lastAction;
		},
		actionsCall: function (lastAction) {
			this.lastAction = function () {
				if (typeof lastAction === "function") { lastAction(); }
			};
			this.lastAction();
		},
		isOngoingCall : function () {
		return	(this.tConn && this.tConn._status === "open")
		},
		updateCountriesPreferred : function () {
			$('#number').intlTelInput("updatePreferredCountries");
		},
		onCallStopSound : function () {
			if(typeof threeSixtyPlayer != "undefined"){
				var self = threeSixtyPlayer;
		        if(self.lastSound != null && self.lastSound.playState && !self.lastSound.paused ){
                    self.lastSound.stop();
                }      		
			}
		},

		//Conference method starts here

		registerCall: function (call_sid) {
			this.call = call_sid;
		},
		handleHold: function () {
			$("#failed_hold").hide();
			if (this.tConn && this.call ) {
				this.toggleWidgetOnHold(false);
				this.isHold ? this.unhold() : this.hold();
				this.isHold ^= 1;
			} else {
				this.resetHoldUI();
			}
		},
		resetHold: function() {
			this.isHold ^= 1;
			this.resetHoldUI();
		},
		resetHoldUI: function() {
			$("#hold").removeClass('active');
			$("#failed_hold").hide();
			this.toggleWidgetOnHold(true);
		},
    hold: function () {
      //Call hold
      var self = this;
      $.ajax({
        dataType: "json",
        data: { "CallSid": self.call },
        url: '/freshfone/hold/add',
        success: function(data) {
          if (data.status != 'hold_initiated') {
          	self.resetHold();
          	if (self.tConn) { $("#failed_hold").show(); }
          }
        },
        error: function () {
          self.resetHold();
          if (self.tConn) { $("#failed_hold").show(); }
        }
      });
    },
		unhold: function () {
			var self = this;
      $.ajax({
        dataType: "json",
        data: { "CallSid": self.call },
        url: '/freshfone/hold/remove',
        success: function(data) {
        },
        failure: function () {
        	self.resetHold();
        }
      });
		},
		toggleWidgetOnHold: function(holded) {
			var self = this;
			if(holded) {
				$('.freshfone_widget .end_call, .freshfone_widget .transfer_call, .freshfone_widget .hold').removeClass('disabled');
					$('.freshfone_widget .hold').removeClass('loading');
			} else {
				$('.freshfone_widget .end_call, .freshfone_widget .transfer_call, .freshfone_widget .hold').addClass('disabled');
				$('.freshfone_widget .hold').addClass('loading');
				setTimeout(function() { 
					self.toggleWidgetOnHold(true);
				}, 10000);
			}
		},
		connectCall: function (params) {
			Twilio.Device.connect(params);
			this.callInitiationTime = new Date();
		},
		getDialCallSid: function() {
			return this.tConn.parameters.CallSid;
		},
		//Conference methods ends here
		isCallActive : function () {
			return (this.status == callStatus.ACTIVECALL);
		},
		resetCallTransferTimer: function() {
			if((this.freshfoneCallTransfer == {}) || (typeof this.freshfoneCallTransfer == "undefined")) {return};
			if (freshfonecalls.freshfoneCallTransfer  instanceof FreshfoneCallTransfer) {
				this.freshfoneCallTransfer.cleanUpTimer();	
			}
		}

	};
}(jQuery));