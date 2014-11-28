(function ($) {
  "use strict";


  $(document).ready(function () {
    $('body').on('click', 'a[href="/logout"]', function (ev) {
      ev.preventDefault();
      czentrix_widget.logout();
    });
    
  });
}(jQuery));
//test comments