var FreshfoneCalls;
(function ($) {
    "use strict";
	var callDirection = { NONE : 0, INCOMING : 1, OUTGOING : 2 },
		callStatus = { NONE: 0, INCOMINGINIT : 1, OUTGOINGINIT : 2, ACTIVECALL : 3, AVAILABLE : 4 },
		numbersHash = freshfone.numbersHash;
	FreshfoneCalls = function (timer, freshfoneUserInfo) {
		this.init();
		this.timer = timer;
		this.currentUser = freshfone.current_user;
		this.ALLOWED_DIGITS = 15;
		this.cached = {};
		this.freshfoneUserInfo = freshfoneUserInfo;
	};

	FreshfoneCalls.prototype = {
		init: function () {
			this.tConn = false;
			this.isMute = 0;
			this.status = callStatus.NONE;
			this.direction = callDirection.NONE;
			this.callerId = null;
			this.callerName = null;
			this.callSid = null;
			this.number = "";
			this.error = null;
			this.errorcode = null;
			this.transfered = false;
			this.recordingInstance = null;
			$('#transfer_call .transfering_call').hide();
		},
		$container: $('.freshfone_content_container'),
		$invalidNumberText: function () {
			return this.cached.$invalidNumberText = this.cached.$invalidNumberText ||
																							this.$container.find('.invalid_phone_text');
		},
		$infoText: function () {
			return this.cached.$infoText = this.cached.$infoText ||
																			this.$container.find('.info_message');
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
		$transferAgent: $('#transfer_call .transfering_call'),
		$number: $("#number"),
//		isKeyPressAllowed: function (char) {
//			return ((char >= 48 && char <= 57) || ($.inArray(char, [35, 42, 43]) >= 0)) &&
//			($('#number').val().length < this.ALLOWED_DIGITS);
//		},

		isMaxSizeReached: function () {
			return (this.$number.val().length < this.ALLOWED_DIGITS);
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
		},
		setDirectionOutgoing: function () {
			this.direction = callDirection.OUTGOING;
		},
		getCallSid: function () {
			return this.callSid || this.tConn.parameters.CallSid;
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
		recordMessage: function (messageSelector) {
			this.recordingInstance = messageSelector;
			if(!this.credit_balance()) {
				return false;
			}
			var self = this;
			this.setDirectionOutgoing();
			this.actionsCall(function () { Twilio.Device.connect({ record: true, agent: self.currentUser }); } );
			
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
		credit_balance: function() {
			var balance_available = false;
			$.ajax({
				url: '/freshfone/credit_balance',
				dataType: "json",
				async: false,
				success: function (result) {
					if (result.credit_balance) { balance_available = true; }
				}
			});
			if (!balance_available) { this.$infoText().show(); }
			return balance_available;
		},
		makeCall: function () {
			if (Twilio.Device.status() !== 'busy') {
				this.number = this.$number.val();
				this.makeOutgoing();
			}
		},
		makeOutgoing: function () {
			if (!this.canDialNumber()) { return this.toggleInvalidNumberText(true); }
			this.number = formatE164(this.callerLocation(), this.number);
			
			var params = { PhoneNumber : this.number, phone_country: this.callerLocation(),
										number_id: this.outgoingNumberId(), agent: this.currentUser };

			if(!this.credit_balance()) {
				return false;
			}
			this.actionsCall(function () { Twilio.Device.connect(params); } );
			

			this.$infoText().hide();
			this.toggleInvalidNumberText(false);

			this.status = callStatus.OUTGOINGINIT;
			this.setDirectionOutgoing();
			this.freshfoneUserInfo.userInfo(this.number, true, this);
		},

		toggleInvalidNumberText: function (show) {
			this.$invalidNumberText().toggle(show || false);
		},

		canDialNumber: function () {
			return (this.number !== this.outgoingNumber()) && isValidNumber(this.number);
		},

		previewIvr: function (id) {
			var params = {
				preview: true,
				id: id
			};
			if(!this.credit_balance()) {
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
		},
		mute: function () {
			if (this.tConn) {
				this.isMute ? this.tConn.unmute() : this.tConn.mute();
				this.isMute ^= 1;
			}
		},
		transferCall: function (id) {
			var self = this;
			id = parseInt(id, 10);
			if (!this.tConn || isNaN(id)) { return false; }
			this.$transferAgent.show();
			this.transfered = true;

			$.ajax({
				type: 'POST',
				dataType: "json",
				url: '/freshfone/call_transfer/initiate',
				data: { "call_sid": this.getCallSid(),
								"id": id,
								"outgoing": this.isOutgoing() },
				error: function () { self.transfered = false; }
			});
		},
		transferSuccessFlash: function () {
			if (!this.transfered) { return false; }
			$("#noticeajax").html("<div>Call transfered successfully.</div>").show();
			closeableFlash('#noticeajax');
		},
		dontShowEndCallForm: function () {
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
		}
	};
}(jQuery));