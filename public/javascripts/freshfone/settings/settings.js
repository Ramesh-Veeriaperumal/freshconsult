var FreshfoneMessage;
(function ($) {
	"use strict";
	var settings_json;
	FreshfoneMessage = function (settingsObject, containerClass, prefix) {
		this.containerClass = containerClass;
		this.prefix = prefix;
		this.messageType = settingsObject.messageType;
		if (settingsObject.messageType === undefined) { settingsObject.messageType = 2; }
		this.settingsObject = settingsObject;
		this.init();
	};
	FreshfoneMessage.prototype = {
		init: function () {
			this.buildFromTemplate();
			this.init_setting();
			this.template.find('.attached_file').hide();
			this.template.find('.recorded-message').hide();
			$('.'+ this.containerClass +' .' + this.settingsObject.type).append(this.template);

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
			var template = $('#message-select-template');
			var prefix = replacePrefix(this.prefix, 'type', this.settingsObject.type);
			var templateOptions = $.extend({}, this.settingsObject, prefix);
			this.template = $.tmpl(template, templateOptions);
		},
		handleAttachmentsDelete: function (id) {
		},
		init_setting: function(){

				$('.queue_setting_div').toggle(!($('#admin_freshfone_number_max_queue_length').val()==="0"));
				$('.voicmail_message_div').toggle(!($('#admin_freshfone_number_voicemail_active_false').is(":checked")===true));
				$('.recording_visibility_div').toggle(!($('#admin_freshfone_number_record_false').is(":checked")===true));
				// $('.non_business_hours_message_container').toggle(!($('#admin_freshfone_number_non_business_hour_calls_false').is(":checked")===true));
		}
	};

	$(freshfone.number_message_settings_json).each(function () {
		var setting = new FreshfoneMessage(this, 'number-settings', freshfone.number_settings_prefix);
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
	$('#admin_freshfone_number_max_queue_length').change(function(){
			($('#admin_freshfone_number_max_queue_length').val()==="0") ? $('.queue_setting_div').slideUp() : $('.queue_setting_div').slideDown();
			
	});
	$("input[name='admin_freshfone_number[voicemail_active]']:radio").change(function(){
		($(this).val() === 'true') ? $('.voicmail_message_div').slideDown() : $('.voicmail_message_div').slideUp();
	});
	
	$("input[name='admin_freshfone_number[record]']:radio").change(function(){
		($(this).val() === 'true') ? $('.recording_visibility_div').slideDown() : $('.recording_visibility_div').slideUp();
	});
	
	$("input[name='non_business_hour_calls']:radio").change(function(){
		if($(this).val() === 'true'){
			$('.non_business_hours_message_container').slideUp();
			$('.multi_business_hours').hide();
			$('.non_business_hours_message').hide();
		}else{
			$('.multi_business_hours').show();
			$('.non_business_hours_message').show();
			$('.non_business_hours_message_container').slideDown();
		}
		
	});

	
	
	function replacePrefix(source, replaceText, replaceWith) {
		var replaceFiller = new RegExp('\\$\\{' + replaceText + '\\}');
		source = $.extend({}, source); // clone
		for(var prefix in source) {
			source[prefix] = source[prefix].replace(replaceFiller, replaceWith);
		}
		return source;
	}
}(jQuery));