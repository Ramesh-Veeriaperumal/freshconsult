(function ($) {
  "use strict";
  $(document).ready(function () {
    $('body').on('click', '.can-make-calls', function (ev) {
      ev.preventDefault();
      if ($(this).data('phoneNumber') !== undefined) {
        var win = document.getElementById("czentrixIframe").contentWindow;
        win.postMessage('0'+ $(this).data('phoneNumber'),"http://"+cti_user.host_ip);
      }
    });
  });
}(jQuery));