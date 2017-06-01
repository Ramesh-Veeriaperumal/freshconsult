(function ($) {
  "use strict";
  $(document).ready(function () {
    $('body').on('click', '.can-make-calls', function (ev) {
      ev.preventDefault();
      if ($(this).data('phoneNumber') !== undefined) {
        var win = document.getElementById("czentrixIframe").contentWindow;
        win.postMessage(''+ $(this).data('phoneNumber'),location.protocol + "//" + cti_user.host_ip);
        var tim = setTimeout(function(){
              jQuery("#cust_det").trigger("click");
              },1000);
      }
    });
  });
}(jQuery));