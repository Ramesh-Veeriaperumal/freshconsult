var FreshfoneUserInfo;
(function ($) {
	// "use strict";
	var customerNumber;

  var strangeNumber;
	FreshfoneUserInfo = function () {
		this.init();
	};
	FreshfoneUserInfo.prototype = {
		init: function () {
			this.number = null;
			this.isOutgoing = null;
			this.callingObject = null;
			this.blankUserAvatar = $('<div />').addClass('preview_pic unknown_user_hover')
															.html($('<img />').attr('src', PROFILE_BLANK_THUMB_PATH));
		},
		$contactTemplate: $('#freshfone-contact-template'),
		$contactTemplateNameless: $('#ffone-contact-template-nameless'),
		$callMetaTemplate: $('#freshfone-call-meta-template'),
		$callWasAnsweredTemplate: $("#freshfone-call-picked-template"),
		$transferMetaTemplate: $("#freshfone-call-transfer-template"),
		$callContext: $('#freshfone-call-context'),
		setRequestObject: function (requestObject) {
			this.requestObject = requestObject;
		},
		userInfo: function (number, outgoing, requestObject) {
			this.customerNumber = number;
			this.isOutgoing = outgoing;
			if (requestObject) { this.requestObject = requestObject; }
			var params = {
				PhoneNumber : this.customerNumber,
				outgoing : this.isOutgoing,
				callerName: null,
				formattedNumber: this.formattedNumber(),
				callerLocation: this.callerLocation(),
				strangeNumber : freshfonewidget.classForStrangeNumbers(this.customerNumber)
			};

			this.removeExistingPopup();
			this.fetchUserDetails(params);
		},
		fetchUserDetails: function (params) {
			var self = this;
			$.ajax({
				url: '/freshfone/call/caller_data',
				dataType: "json",
				data: params,
				async: true,
				success: function (data) {
					if (data) {
						self.requestObject.callerName = data.user_name;
						self.requestObject.callerId = data.user_id;
						self.requestObject.avatar = data.user_hover || false;
						self.requestObject.callMeta = self.construct_meta(data.call_meta);
						self.requestObject.transferAgentName = data.call_meta.transfer_agent.user_name;
						self.requestObject.ffNumberName = (data.call_meta || {}).number || "";
						self.setOngoingCallContext(data.call_meta.caller_location);
					}
					if (self.isOutgoing) {						
						self.setOngoingStatusAvatar(self.requestObject.avatar || self.blankUserAvatar);
					} else {
						params.callerName = self.requestObject.callerName;
						params.callMeta = self.requestObject.callMeta;
						self.buildContactTemplate(params);
						if (data.call_meta){ 
							freshfone.ringing_time = data.call_meta.ringing_time;
							if (data.call_meta.transfer_agent) {
								freshfonecalls.setIsIncomingTransfer(true);
								self.fillTransferAgent(data.call_meta.transfer_agent);
							}else{
								freshfonecalls.setIsIncomingTransfer(false);
							}
						}
					}
					self.unknownUserFiller();
				}
			});
		},
		construct_meta: function (meta) {
			var call_meta = {};
			if (meta) {
				number = meta.number || "";
				group  = meta.group  || "";
				call_meta = {"ff_number_info": number, "ff_group_info": group, "company_name": meta.company_name};
			}
			return call_meta;
		},
		removeExistingPopup: function () {
			var popover = $('.unknown_user_hover').data('popover') ||
										$('#incall_user_info .username').data('popover');
			if (popover !== undefined) { popover.tip().remove(); }
		},
		unknownUserFiller: function () {
			customerNumber = this.customerNumber;
			strangeNumber = freshfonewidget.classForStrangeNumbers(this.customerNumber);
			$('.unknown_user_hover').popover({
				placement: 'above',
				html: true,
				reloadContent: true,
				template: '<div class="dbl_left arrow"></div><div class="hover_card contact_hover inner"><div class="content"><p></p></div></div>',
				content: this.userContactHover
			});
		},
		setOngoingStatusAvatar: function (avatar) {
			if ($('#incall_user_info')) {
				$('#incall_user_info').html($(avatar).clone());
				this.unknownUserFiller();
			}
		},
		setOngoingCallContext: function(location){
			var callerName = this.requestObject.callerName==this.customerNumber? "ANONYMOUS" : this.requestObject.callerName;
			var callerId = this.requestObject.callerId;
			var params = {callerName: callerName, 
							callerNumber: this.formattedNumber(), 
							callerLocation: location,
							callerId: callerId
						};
			var template = this.$callContext.clone();
			freshfonewidget.callerUserId = callerId;
			$('.caller-context-details').html(template.tmpl(params));
		},
		formattedNumber: function () {
			return formatInternational(this.callerLocation(), this.customerNumber)
		},
		callerLocation: function () {
			return countryForE164Number(this.customerNumber)
		},
		prefillContactTemplate: function (number) {
			this.customerNumber = number;
			var template = this.$contactTemplateNameless.clone(),
				params = {
					formattedNumber: this.formattedNumber(),
					callerLocation: this.callerLocation()
				};

			this.requestObject.$userInfoContainer.find('.customer-info').html(template.tmpl(params));
			this.setBlankProfileImage()
		},
		buildContactTemplate: function (params) {
			var template = this.requestObject.callerName ? this.$contactTemplate.clone() : this.$contactTemplateNameless.clone();
			var metaTemplate = this.$callMetaTemplate.clone();
			this.requestObject.$userInfoContainer.find('.customer-info').html(template.tmpl(params));
			this.requestObject.$userInfoContainer.find('.call-meta').html(metaTemplate.tmpl(params.callMeta));
			if (this.requestObject.avatar) {
				var avatar = $(this.requestObject.avatar).find('img');
				this.requestObject.$userInfoContainer.find('.user_avatar')
					.html(avatar);
			} else {
				this.setBlankProfileImage();
			}
			this.requestObject.createDesktopNotification();
		},
		setBlankProfileImage: function () {
			this.requestObject.$userInfoContainer.find('.incoming-details .user_avatar')
				.html($('<img />').attr('src', PROFILE_BLANK_THUMB_PATH));
		},
		fillTransferAgent: function (params) {
			var template = $("#freshfone-transfer-call-notifier").clone();
			this.requestObject.$userInfoContainer.find('.transfer-details').html(template.tmpl(params));
		},
		userContactHover: function () {
			var template = "<span><div class='infoblock'><div class='preview_pic' size_type='thumb'></div><div class='user_name ${strangeNumber}'>${number}</div></div></span>",
				$div = $("<div />")
							.append($(template)
												.tmpl({ number: customerNumber, strangeNumber: strangeNumber  }));
			$div.find('.preview_pic').html($('.unknown_user_hover').html());
			return $div.html();
		},
		setCallPickedAlert: function(agent){
			var domTemplate = this.$callWasAnsweredTemplate.clone();
			domTemplate = domTemplate.tmpl({agent: agent});
			if (this.requestObject.$userInfoContainer)
				this.requestObject.$userInfoContainer.find('.incoming-details').html(domTemplate);
		},
		setTransferMeta: function (type, agent) {
			var metaTemplate = this.$transferMetaTemplate.clone(),
			params = {transferType: type.capitalize(), sourceAgent: agent};
			this.requestObject.$userInfoContainer.find('.transfer-meta')
			.html(metaTemplate.tmpl(params))
			.toggle(true);
		}
	};
}(jQuery));