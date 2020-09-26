(function ($) {
	"use strict";
	var timeout,
		longpress,
		$number = $('.ff-dial-pad #number');
	
//Invoking intlTelInput plugin 
    window.tel = $number.intlTelInput(); 
 // Invoking keypad
	$number.keypad({
		keypadOnly: false,
		callText: 'Call',
		callStatus: 'Make calls',
		backStatus: 'Delete',
		backText: 'X',
		layout: ['123', '456', '789', '*0#'],
		showAnim: 'show',
		// showOptions: {direction : 'up'},
		keypadClass: 'freshfone_dialpad',
		duration: 'fast',
		showOn: 'none',
		onKeypress: function (key, value, inst) {
			if (freshfonecalls.isOngoingCall()) {
				freshfonecalls.tConn.sendDigits(key);
			}
			clearTimeout(timeout);
			longpress = false;
		},
		onMousedown: function (keypad, inst) {
			var searchString = $number.val() + $(this).html();
			freshfoneDialpadEvents.bindSearchResult(searchString);
			
			$number.intlTelInput("updateFlag");
			freshfonecalls.hideText();
			if($(this).attr('class').indexOf("keypad-call") == -1){
				freshfonecalls.exceptionalNumber = false;
			}
			$number.intlTelInput("updateFlag");
      if (!freshfonecalls.isOngoingCall() && freshfonecalls.isMaxSizeReached()) {
			 return (keypad.preventDefault = true); 
			}
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
		freshfonecalls.hideText();
		var key = String.fromCharCode(ev.charCode), key_element;
		
		
		if (freshfonecalls.isOngoingCall()) {
			freshfonecalls.tConn.sendDigits(key);
		} else if (freshfonecalls.isMaxSizeReached()) {
			 return ev.preventDefault(); 
		}
		
		
		if (key === "+") { key = "0"; }
		
		if (key != ('('||')')){ 
			key_element = $('.freshfone_dialpad').find('.keypad-key:contains(' + key + ')'); 
			key_element.addClass('keypad-key-down');
			setTimeout(function () { key_element.removeClass('keypad-key-down'); }, 200);
		}

		freshfonecalls.toggleInvalidNumberText(false);

	}).bind('paste', function (ev) {

		if (freshfonecalls.isMaxSizeReached()) { return ev.preventDefault(); }
		freshfonecalls.toggleInvalidNumberText(false);
		
		setTimeout(function () { freshfonecalls.removeExtraCharacters(); }, 1);
		// setTimeout(function () { freshfonecalls.removeDisallowedCharacters(); }, 1);
	}).keydown(function(ev){	
		var key = ev.keyCode;
		if (key == 38 || key == 40){
			freshfoneDialpadEvents.nextElement(key);
		} else {			
			if(key == 8) {	freshfonecalls.hideText(); }
			freshfonecalls.exceptionalNumber = false; 	
		}	
	}).keyup(function(ev){
		if(ev.keyCode == 13){	freshfoneDialpadEvents.bindEnterEvent(); }
	});
	
	
	// Dialpad show
	$('.ongoingDialpad, .showDialpad')
		.on('shown', function (e) {
			freshfoneMetricsOnKeyPress();
			if(freshfonecalls.recentCaller != 1){  
				$number.val("");
			} else {
				freshfonecalls.recentCaller = 0;
			}

			$number.intlTelInput("setPreferredCountries");
			freshfonecalls.hideText();
	});

	function freshfoneMetricsOnKeyPress(){
		jQuery(".user_phone").keypress(function(ev){
				if(ev.keyCode===13){
					App.Phone.Metrics.resetCallDirection();
					App.Phone.Metrics.resetConvertedToTicket();
				}
			});
	}


}(jQuery));