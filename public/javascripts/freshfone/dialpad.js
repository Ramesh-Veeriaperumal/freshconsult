(function ($) {
	"use strict";
	var timeout,
		longpress,
		$number = $('#number'),
		$callButtonContainer;
	
	// Defining two custom keys
	$.keypad.addKeyDef('CALL', 'call', function (inst) { freshfonecalls.makeCall(); });
	
 // Invoking keypad
	$number.keypad({
		keypadOnly: false,
		callText: 'Call',
		callStatus: 'Make calls',
		backStatus: 'Delete',
		backText: 'X',
		layout: ['123', '456', '789', '*0#',  $.keypad.CALL, $.keypad.BACK ],
		showAnim: 'show',
		// showOptions: {direction : 'up'},
		keypadClass: 'freshfone_dialpad',
		duration: 'fast',
		showOn: 'none',
		onKeypress: function (key, value, inst) {
			if (freshfonecalls.tConn && freshfonecalls.tConn._status === "open") {
				freshfonecalls.tConn.sendDigits(key);
			}
			clearTimeout(timeout);
			longpress = false;
		},
		onMousedown: function (keypad, inst) {

			if (!freshfonecalls.isMaxSizeReached()) { return (keypad.preventDefault = true); }
			freshfonecalls.toggleInvalidNumberText(false);

			if ($(this).html() === "0") {
				timeout = setTimeout(function () {
					longpress = true;
					keypad.preventDefault = true;
					keypad._selectValue(inst, "+");
				}, 500);
			}
		}
	}).keypress(function (ev) {

		if (ev.keyCode === 13) { return freshfonecalls.makeCall(); }
		
		var key = String.fromCharCode(ev.charCode), key_element;
		
		if (!freshfonecalls.isMaxSizeReached()) { return ev.preventDefault(); }
          
		if (freshfonecalls.tConn && freshfonecalls.tConn._status === "open") {
			freshfonecalls.tConn.sendDigits(key);
		}
		
		if (key === "+") { key = "0"; }
		
		key_element = $('.freshfone_dialpad').find('.keypad-key:contains(' + key + ')');
		key_element.addClass('keypad-key-down');
		setTimeout(function () { key_element.removeClass('keypad-key-down'); }, 200);
		freshfonecalls.toggleInvalidNumberText(false);

	}).bind('paste', function (ev) {

		if (!freshfonecalls.isMaxSizeReached()) { return ev.preventDefault(); }
		freshfonecalls.toggleInvalidNumberText(false);
		
		setTimeout(function () { freshfonecalls.removeExtraCharacters(); }, 1);
		// setTimeout(function () { freshfonecalls.removeDisallowedCharacters(); }, 1);
	});
	
	
	// Dialpad show
	$('.ongoingDialpad, .showDialpad')
		.on('shown', function (e) {
			$number.keypad('show');
			$callButtonContainer = $('.freshfone_dialpad .keypad-call').parent();

			if ($(this).hasClass('showDialpad')) {
				$callButtonContainer.show();
				freshfonecalls.enableOrDisableCallButton();
			} else {
				$callButtonContainer.hide();
			}

		}).on('hidden', function (e) {
			$number.keypad('hide');
		});
}(jQuery));