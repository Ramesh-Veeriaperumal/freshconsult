(function ($) {
	"use strict";
	var timeout,
		longpress,
		$number = $('#number'),
		$callButtonContainer;
	
	// Defining two custom keys
//Invoking intlTelInput plugin 
    window.tel = $number.intlTelInput(); 
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
			freshfoneMetricsOnClick($(this));
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
		if (ev.keyCode === 13) { 
			return freshfonecalls.makeCall(); }
		else{
			freshfonecalls.exceptionalNumber = false;
		}

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
	}).keyup(function(ev){
		if(ev.keyCode == 8){
			freshfonecalls.hideText();
		}
	});
	
	
	// Dialpad show
	$('.ongoingDialpad, .showDialpad')
		.on('shown', function (e) {
			freshfoneMetricsOnKeyPress();
			freshfoneMetricsOnPaste();
			$number.keypad('show');
			$number.intlTelInput("setPreferredCountries");
			freshfonecalls.hideText();
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
            if (! $.isEmptyObject(freshfone.numbersHash)) {
            	freshfonewidget.outgoingCallWidget.toggle(true);
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
	           } else { 
	           	freshfonewidget.outgoingCallWidget.toggle(false);
	           }
            
       });
	
	function freshfoneMetricsOnClick(classValue){
		if(classValue.hasClass('keypad-key')){
				if(freshfonecalls.isOngoingCall()){
					App.Phone.Metrics.recordSource("CLICK_IVR");
					App.Phone.Metrics.push_event();
				}
				else{
					App.Phone.Metrics.recordSource("DIAL_BY_NUM_PAD");
				}
			}
			if(classValue.hasClass('keypad-special')){
				App.Phone.Metrics.push_event();
			}
	}

	function freshfoneMetricsOnKeyPress(){
		jQuery(".user_phone").keypress(function(ev){
				if(ev.keyCode===13){
					App.Phone.Metrics.push_event();
				}
				else{
					if(freshfonecalls.isOngoingCall()){
						App.Phone.Metrics.recordSource("KEY_IVR");
						App.Phone.Metrics.push_event();
					}
					else{
						App.Phone.Metrics.recordSource("DIAL_BY_KEY");
					}
				}
			});
	}

	function freshfoneMetricsOnPaste(){
		$(".user_phone").bind('paste', function() {
   			App.Phone.Metrics.recordSource("DIAL_BY_NUM_PASTE");
		});
	}

}(jQuery));