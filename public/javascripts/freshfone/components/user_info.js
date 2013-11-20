var FreshfoneUserInfo;
(function ($) {
	"use strict";
	var customerNumber;

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
				callerLocation: this.callerLocation()
			};

			this.removeExistingPopup();
			this.fetchUserDetails(params);
		},
		fetchUserDetails: function (params) {
			var self = this;
			$.ajax({
				url: '/contacts/freshfone_user_info',
				dataType: "json",
				data: params,
				async: true,
				success: function (data) {
					if (data) {
						self.requestObject.callerName = data.user_name;
						self.requestObject.callerId = data.user_id;
						self.requestObject.avatar = data.user_hover || false;
					}
					if (self.isOutgoing) {
						self.setOngoingStatusAvatar(self.requestObject.avatar || self.blankUserAvatar);
					} else {
						params.callerName = self.requestObject.callerName;
						self.buildContactTemplate(params);
					}
					self.unknownUserFiller();
				}
			});
		},
		removeExistingPopup: function () {
			var popover = $('.unknown_user_hover').data('popover') ||
										$('#incall_user_info .username').data('popover');
			if (popover !== undefined) { popover.tip().remove(); }
		},
		unknownUserFiller: function () {
			customerNumber = this.customerNumber;
			$('.unknown_user_hover').popover({
				placement: 'above',
				html: true,
				reloadContent: true,
				template: '<div class="dbl_left arrow"></div><div class="hover_card contact_hover inner"><div class="content"><p></p></div></div>',
				content: this.userContactHover
			});
		},
		setOngoingStatusAvatar: function (avatar) {
			if (freshfonewidget.ongoingCallWidget.find('#incall_user_info')) {
				freshfonewidget.ongoingCallWidget.find('#incall_user_info').html($(avatar).clone());
				this.unknownUserFiller();
			}
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

			this.requestObject.$userInfoContainer.find('.customer').html(template.tmpl(params));
			this.setBlankProfileImage()
		},
		buildContactTemplate: function (params) {
			var template = this.requestObject.callerName ? this.$contactTemplate.clone() : this.$contactTemplateNameless.clone();

			this.requestObject.$userInfoContainer.find('.customer').html(template.tmpl(params));
			if (this.requestObject.avatar) {
				var avatar = $(this.requestObject.avatar).find('img');
				this.requestObject.$userInfoContainer.find('.avatar')
					.html(avatar);
			} else {
				this.setBlankProfileImage();
			}
		},
		setBlankProfileImage: function () {
			this.requestObject.$userInfoContainer.find('.avatar')
				.html($('<img />').attr('src', PROFILE_BLANK_THUMB_PATH));
		},

		userContactHover: function () {
			var template = "<span><div class='infoblock'><div class='preview_pic' size_type='thumb'></div><div class='user_name'>${number}</div></div></span>",
				$div = $("<div />")
							.append($(template)
												.tmpl({ number: customerNumber }));
			$div.find('.preview_pic').html($('.unknown_user_hover').html());
			return $div.html();
		}
		
		
	};
}(jQuery));