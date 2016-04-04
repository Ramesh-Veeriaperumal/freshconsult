(function ($) {
  "use strict";
  $(document).ready(function () {
    $('body').on('click', '.can-make-calls', function (ev) {
      ev.preventDefault();
      if ($(this).data('phoneNumber') !== undefined) {
        var numberToCall = ($(this).data('phoneNumber')).toString();
        makePhoneCall(cti_user.number, numberToCall);
        freshdeskShowCrm(numberToCall);
        $('.no-call-msg').addClass('hide');
      }
    });
  });
}(jQuery));