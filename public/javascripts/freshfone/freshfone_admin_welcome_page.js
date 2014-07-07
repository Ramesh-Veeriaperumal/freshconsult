(function ($) {
  "use strict";
  var $freshfone_feature_request = $('#freshfone_feature_request'),
      $freshfone_flash = $('#ff_feature_request');
  $freshfone_feature_request.on('click', function () {
    var self = this;
    $(self).addClass('disabled');
    $(".small_note").hide();
    $.ajax({
      url: '/admin/freshfone/request_freshfone_feature',
      type: "post",
      success: function () {
        $freshfone_flash
          .html(freshfone.request_success_message)
          .addClass('success_flash')
          .removeClass('error_flash')
          .show();
      },
      error: function () {
        $(self).button('reset');
        $freshfone_flash
          .html(freshfone.request_error_message)
          .addClass('error_flash')
          .removeClass('hide')
          .show();
      }
    });
  });
}(jQuery));