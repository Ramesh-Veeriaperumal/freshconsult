var FreshfoneMessage;
(function ($) {
	"use strict";
	var settings_json;
	FreshfoneMessage = function (settingsObject, containerClass, prefix) {
		this.containerClass = containerClass;
		this.prefix = prefix;
		this.messageType = settingsObject.messageType;
		if (settingsObject.messageType === undefined) { settingsObject.messageType = this.selectMessageType(settingsObject); }
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
			var elements = ["wait_message", "hold_message"];
			if (elements.include(this.settingsObject.type)) {
				this.template.find('.remove_attachment').hide();
				this.template.find('[rel=attachment_id]').val('');
			}
		},
		init_setting: function(){

				$('.queue_setting_div').toggle(!($('#admin_freshfone_number_max_queue_length').val()==="0"));
				$('.voicmail_message_div').toggle(!($('#admin_freshfone_number_voicemail_active_false').is(":checked")===true));
				$('.recording_visibility_div').toggle(!($('#admin_freshfone_number_record_false').is(":checked")===true));
				$('.queue_setting_div #admin_freshfone_number_queue_position_preference').itoggle();
				$('.queue_position_message_div').toggle($("#admin_freshfone_number_queue_position_preference").is(":checked"));
				this.removeOptions();
				// $('.non_business_hours_message_container').toggle(!($('#admin_freshfone_number_non_business_hour_calls_false').is(":checked")===true));
		},
		removeOptions: function() {
			var elements = ["wait_message", "hold_message"];
			if (elements.include(this.settingsObject.type)) {
				this.template.find(".upload_voice").addClass("current hide");
				this.template.find(".read_message").remove();
				this.template.find(".message-input").remove();
				this.template.find(".message-recording").remove();
				this.template.find(".record_voice").remove();
			}
		},
		selectMessageType: function (settingsObject) {
			var elements = ["wait_message", "hold_message"];
			return elements.include(settingsObject.type) ? 1 : 2;	
			
		}
	};

	$(freshfone.number_message_settings_json).each(function () {
		var setting = new FreshfoneMessage(this, 'number-settings', freshfone.number_settings_prefix);
	});
	
	$('.number-settings').submit(function (ev) {
		// 'Secure' IE forced hack
		if (!$.browser.msie) {
			ev.preventDefault();
			setGroupIds();
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

	$('#admin_freshfone_number_queue_position_preference').change(function(){
		($("#admin_freshfone_number_queue_position_preference").is(":checked")) ?  $('.queue_position_message_div').slideDown() : $('.queue_position_message_div').slideUp();
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
	$("#selectGroupAccess").on('click', function(e){
		$("#s2id_access_groups").toggle(true);
		$("#defaultGroupAccess").toggle(false);
		e.preventDefault();
	});
	$(window).on('load',function() {
		$("#access_groups").select2();
		freshfone.old_groups_list = $("#access_groups").val() || [];
		if (freshfone.old_groups_list.length == 0) {
			$("#s2id_access_groups").toggle(false);
			$("#defaultGroupAccess").toggle(true);
		}
	});
	function setGroupIds () {
		var new_list = [], 
				added_agents=[], 
				removed_agents = [],
				old_list = freshfone.old_groups_list;
		new_list = jQuery("#access_groups").val() || [];
		make_group_list(new_list,old_list,added_agents);
		make_group_list(old_list,new_list,removed_agents);
		$("#added_list").val(String(added_agents));
		$("#removed_list").val(String(removed_agents));
	}
	
	function make_group_list(array1,array2,result_array) {
		$.grep(array1, function(el) {
			if ($.inArray(el, array2) == -1) result_array.push(el);
		});
	}

	function replacePrefix(source, replaceText, replaceWith) {
		var replaceFiller = new RegExp('\\$\\{' + replaceText + '\\}');
		source = $.extend({}, source); // clone
		for(var prefix in source) {
			source[prefix] = source[prefix].replace(replaceFiller, replaceWith);
		}
		return source;
	}
}(jQuery));