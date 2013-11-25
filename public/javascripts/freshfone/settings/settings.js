(function ($) {
	"use strict";
	var settings_json,
		FreshfoneSetting = function (settingsObject) {

			settingsObject.messageType = settingsObject.messageType;
			if (settingsObject.messageType === undefined) { settingsObject.messageType = 2; }
			this.settingsObject = settingsObject;
			this.init();
		};
	FreshfoneSetting.prototype = {
		init: function () {
			this.buildFromTemplate();
			this.template.find('.attached_file').hide();
			this.template.find('.recorded-message').hide();
			$('.number-settings .greetings .' + this.settingsObject.type).append(this.template);
			this.template.messageSelector({
				attachmentName: this.settingsObject.attachmentName,
				recordingUrl: this.settingsObject.recordingUrl,
				attachmentId: this.settingsObject.attachmentId,
				attachmentUrl: this.settingsObject.attachmentUrl,
				attachementDeleteCallback: this.handleAttachmentsDelete,
				attachementDeleteCallbackContext: this
			});
		},
		buildFromTemplate: function () {
			var template = $('.message-container-template').clone(true, true);
			this.template = template.tmpl(this.settingsObject);
		},
		handleAttachmentsDelete: function (id) {
		}
	};

	$(freshfone.number_message_settings_json).each(function () {
		var setting = new FreshfoneSetting(this);
	});
	
	$('.number-settings').submit(function (ev) {
		// 'Secure' IE forced hack
		if (!$.browser.msie) {
			ev.preventDefault();

			$('.number-settings').ajaxSubmit({
				dataType: 'json',
				async: false,
				beforeSubmit: function (arr, $form) {
					setPostParam($form, "format", "json");
				},
				success: function (data, statusText, xhr, $form) {
					if (data.status === "success") {
						window.location.reload(true);
					} else {
						$form.find('#errorExplanation').remove();
						$form.prepend(data.error_message);
					}
				},
				error: function (data) {
					
				}
			});
			
		}
	});
	

}(jQuery));