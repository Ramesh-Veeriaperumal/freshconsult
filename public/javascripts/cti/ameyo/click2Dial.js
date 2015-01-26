(function ($) {
  "use strict";
  $(document).ready(function () {
    $('body').on('click', '.can-make-calls', function (ev) {
      ev.preventDefault();
      if ($(this).data('phoneNumber') !== undefined) {
        populateNumberInDialBox($(this).data('phoneNumber').toString());
        var tim = setTimeout(function(){
              jQuery("#cust_det").trigger("click");
              },1000);
      }
    });
  });
}(jQuery));