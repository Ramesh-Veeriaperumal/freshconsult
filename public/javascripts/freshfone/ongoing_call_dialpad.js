(function ($) {
  "use strict";
  var timeout,
      longpress,
      $ongoing_number = $('#ongoing_number');
  
 // Invoking ongoing call keypad
  $ongoing_number.keypad({
    keypadOnly: false,
    layout: ['123', '456', '789', '*0#'],
    showAnim: 'show',
    keypadClass: 'ongoing_dialpad',
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

      if ($(this).html() === "0") {
        timeout = setTimeout(function () {
          longpress = true;
          keypad.preventDefault = true;
          keypad._selectValue(inst, "+");
        }, 500);
      }
    }
  }).keypress(function (ev) {
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

  }).bind('paste', function (ev) {

    if (freshfonecalls.isMaxSizeReached()) { return ev.preventDefault(); }
    freshfonecalls.toggleInvalidNumberText(false);
    
    setTimeout(function () { freshfonecalls.removeExtraCharacters(); }, 1);
  });

  // Dialpad show
  $('.ongoingDialpad').on('shown', function (e) {
      $ongoing_number.focus().val('');
      $ongoing_number.keypad('show');
  });
}(jQuery));