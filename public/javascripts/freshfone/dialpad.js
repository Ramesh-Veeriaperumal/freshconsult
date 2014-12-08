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
			if (freshfonecalls.isOngoingCall()) {
				freshfonecalls.tConn.sendDigits(key);
			}
			clearTimeout(timeout);
			longpress = false;
		},
		onMousedown: function (keypad, inst) {

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

		if (ev.keyCode === 13) { return freshfonecalls.makeCall(); }
		
		var key = String.fromCharCode(ev.charCode), key_element;
		
		if (freshfonecalls.isOngoingCall()) {
			freshfonecalls.tConn.sendDigits(key);
		} else if (freshfonecalls.isMaxSizeReached()) {
		 return ev.preventDefault(); 
		}
		
		if (key === "+") { key = "0"; }
		
		key_element = $('.freshfone_dialpad').find('.keypad-key:contains(' + key + ')');
		key_element.addClass('keypad-key-down');
		setTimeout(function () { key_element.removeClass('keypad-key-down'); }, 200);
		freshfonecalls.toggleInvalidNumberText(false);

	}).bind('paste', function (ev) {

		if (freshfonecalls.isMaxSizeReached()) { return ev.preventDefault(); }
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
		
		$('.outgoing_numbers_list').on("change",function(){
			var callerIdNumber = $('.outgoing_numbers_list').select2("val");
			localStorage.setItem("callerIdNumber", callerIdNumber);
            $('#outgoing_number_selector').find('.li_opt_selected').removeClass("li_opt_selected");
			$('#outgoing_number_selector option:selected').addClass("li_opt_selected");

        });


        $(document).ready(function(){
            var $outgoing_numbers_list = $('.outgoing_numbers_list');
            
            $outgoing_numbers_list.select2({
            	dropdownCssClass: "outgoing_numbers_list_dropdown",
            	minimumResultsForSearch: 5,
            	attachtoContainerClass: ".popupbox-content",

	            formatResult: function(result, container,query){
                    var name = freshfone.namesHash[result.id],
	            	    number = freshfone.numbersHash[result.id];
	                if(name == ""|| name.trim == "" ){
	            	    return  "<span>" +number + "</span>" ;
                    }else{
	            		return "<span><b>" + name + "</b></span><br/><span>" + number + " </span>" ;    
	            	}
	            },
	            
	            formatSelection: function(data, container) {
	            	var result = data.text;
	            	var lastindex = result.lastIndexOf(" ");
	            	result = (lastindex > -1) ?  result.substring(0, lastindex) : data.text;
                    return result;
                }
            });
            
       });
}(jQuery));