(function ($) {
  "use strict";


  $(document).ready(function () {
    $('body').on('click', 'a[href="/logout"]', function (ev) {
      czentrix_widget.logout();
    });
  });
}(jQuery));
