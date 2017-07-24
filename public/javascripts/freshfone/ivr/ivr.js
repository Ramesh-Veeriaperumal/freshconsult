var Ivr;
(function ($) {
	"use strict";
	Ivr = function () {
		this.$loadingDiv = false;
		this.$ivrDisabledMessage	= $('.ivr-disabled-message');
		this.$ivrEnabledMessage	= $('.ivr-enabled-message');
		this.$welcomeMessage =$('.freshfone_welcome_message_alert');
		this.$ivrSetting = $('.ivr_setting');
        this.$activateIvrToggle = this.$ivrSetting.find('.activate_ivr');
		this.bindTurnOnandTurnOffIvr();
	};
	Ivr.globalkeyslist = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "#", "0", "*"];

	Ivr.prototype = {
		bindTurnOnandTurnOffIvr: function () {
			var self = this;
			this.$ivrDisabledMessage.toggle(!freshfone.is_ivr_active);
			this.$ivrEnabledMessage.toggle(freshfone.is_ivr_active);
			this.$welcomeMessage.toggle(freshfone.is_ivr_active);
			this.$activateIvrToggle.itoggle({
				checkedLabel: freshfone.IVR_TURN_ON_MESSAGE,
				uncheckedLabel: freshfone.IVR_TURN_OFF_MESSAGE
			}).change(function () {
				var url = $(this).is(':checked') ? $(this).data('activate-url') : $(this).data('deactivate-url');
				self.ivrTurnOnorOff(url);
			});
		},
		ivrTurnOnorOff: function (url) {
			var self = this;
			this.showLoadingDiv();
			$.ajax({	type : 'POST',
								dataType: 'script',
								url : url,
								success: function () { self.hideLoadingDiv(); },
								error: function () { self.hideLoadingDiv(); }
				});
		},
		showLoadingDiv: function () {
			this.$ivrSetting.block({
				message: " <h1>...</h1> ",
				css: {
					display: 'none',
					backgroundColor: '#e9e9e9',
					border: 'none',
					color: '#FFFFFF',
					opacity: 0
				},
				overlayCSS: {
					backgroundColor: '#F5F5F5',
					opacity: 0.6
				}
			});
		},
		hideLoadingDiv: function () {
			this.$ivrSetting.unblock();
		},
		menuCreation: function () {
			var menu = new IvrMenu(this).build();
			new IvrOption(this, menu).build();
			$.scrollTo(menu.menu);
		},
		hideAddMenuLink: function (menus) {
			$(menus).each(function (i, menu) {
				if(menu != undefined){
			 			menu.hideAddMenuLink();
			 		}
			 	});
		},
		propagateNameChange: function (menuId, menuName) {
			$('#optionTemplate [rel=IVR]').find('option[value="' + menuId + '"]').text(menuName).change();
			IvrMenu.prototype.menusList.each(function (menu, i) { menu.propagateNameChange(menuId, menuName); });
		},
		addMenuToList: function (menuId, menuName) {
			$('#optionTemplate [rel=IVR]').append($('<option />', { value : menuId, html : menuName }));
			IvrMenu.prototype.menusList.each(function (menu, i) { menu.addMenuToList(menuId, menuName); });
		},
		removeMenuFromList: function (menuId) {
			$('#optionTemplate [rel=IVR]').find('option[value=' + menuId + ']').remove();
			IvrMenu.prototype.menusList.each(function (menu, i) { menu.removeMenuFromList(menuId); });
		},
		buildExistingIvr: function (menu_json) {
			var self = this;
			$(menu_json).each(function () {
				var menu = new IvrMenu(self, this).build();
				$((this.options)).each(function () {
					this.menuId = menu.menuId;
					new IvrOption(self, menu, this).build();
				});
			});
		},
		submitIvr: function (submitButton, $form, preview) {
			if (this.anyErrorInIvrForm()) {return;}
			if(preview){ $('#ivr_submit').addClass("disabled"); }
			var $submitButton = $(submitButton),
				self = this;
			$submitButton.button('loading');
			this.showLoadingDiv();

			$form.ajaxSubmit({
				dataType: 'json',
				async: false,
				beforeSubmit: function (arr, $form) {
					setPostParam($form, "format", "json");
					setPostParam($form, "preview", preview);
				},
				success: function (data) { self.ivrSubmitOnSuccess(data, $submitButton, $form, preview); },
				error: function (data) {
					$submitButton.button('reset');
					self.hideLoadingDiv();
				}
			});
		},
		ivrSubmitOnSuccess: function (data, $submitButton, $form, preview) {
			this.hideLoadingDiv();
			if (data.status === "success") {
				this.successInResponse($submitButton, preview);
			} else {
				this.failureInResponse(data, $submitButton, $form);
			}
		},
		successInResponse: function($submitButton, preview) {
			if (preview && freshfonecalls) { return freshfonecalls.previewIvr($submitButton.data('ivr')); }
			window.location.reload(true);
		},
		failureInResponse: function(data, $submitButton, $form) {
			$form.find('#errorExplanation').remove();
			$form.prepend($(data.error_message));
			$submitButton.button('reset');
		},
		bindDirectDialNumberValidation: function () {
			var self = this;
			$(".number_performer_input").on('blur', function () {
				var element =  $(this);
				self.toggleInvalidNumberError(false, element.next());
			});
			$(".number_performer_input").on('focus', function () {
				self.toggleInvalidNumberError(false, $(this).next());
			});
		},
		toggleInvalidNumberError: function (isVisible, element) {
			isVisible ? element.show() : element.hide();
		},
		anyErrorInIvrForm: function () {
			var self = this, error=false, element, val, formattedNum;
			$(".number_performer_input:visible").each(function () { 
				element = $(this);
				val = element.val();
				if(val) {
					formattedNum = formatE164(countryForE164Number(val), val);
					if(formattedNum && formattedNum != val)
						element.val(formattedNum);
				}
			});
			return error;
		}
	};
}(jQuery));