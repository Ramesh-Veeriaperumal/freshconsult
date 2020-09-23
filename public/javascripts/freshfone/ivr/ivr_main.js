Array.prototype.deleteElement = function (element) {
	if (this.indexOf(element) !== -1) {
		this.splice(this.indexOf(element), 1);
	}
    return this;
};
(function ($) {
	"use strict";
	var ivr,
		formatResultWithDisable,
		preview = false,
		$ivrSubmit = $('#ivr_submit'),
		$ivrPreview = $('#ivr_preview'),
		$ivrForm = $('.edit_freshfone_ivr'),
		$simpleMessageSubmit = $('#simple_message_submit'),
		$simpleMessageForm = $('.ivr_setting.simple_message');

	ivr = new Ivr();
	ivr.buildExistingIvr(menu_json);
	ivr.bindDirectDialNumberValidation();
	$(document).ready(function () {
		$('.new-menu').click(function () { ivr.menuCreation(); });
		var setting = new FreshfoneMessage(freshfone.welcome_message_settings_json, 'ivr_setting',
														freshfone.welcome_message_prefix);
	});

	formatResultWithDisable = function (object, container, query, node) {
		if (object.element[0].disabled) {
			$(object.element[0]).removeClass('select2-result-selectable').addClass('select2-result-unselectable');
		}
		return '<span class="select2-match"></span>' + object.text;
	};

	// Custom select2 with disabled option
	$('form select.custom-keypad-select2').livequery(function () {
		$(this).select2({
			minimumResultsForSearch: 13,
			formatResult: formatResultWithDisable
		});
	});


	$ivrSubmit.click(function (ev) { preview = false; });
	
	$ivrPreview.click(function (ev) { preview = true; });
	
	$ivrForm.submit(function (ev) {
		// 'Secure' IE forced hack
		if (!$.browser.msie) {
			ev.preventDefault();
			var $submitButton = preview ? $ivrPreview : $ivrSubmit;
			ivr.submitIvr($submitButton, $ivrForm, preview);
		}
	});
	$simpleMessageForm.submit(function (ev) {
		// 'Secure' IE forced hack
		if (!$.browser.msie) {
			ev.preventDefault();
			ivr.submitIvr($simpleMessageSubmit, $simpleMessageForm, false);
		}
	});
	$('.welcome_message_select').change(function () {
		var simple = $(this).val() === "0" ? true : false;
		$('.numbers_simple_message').toggle(simple);
		$('.numbers_ivr_message').toggle(!simple);
	});
	
}(jQuery));
