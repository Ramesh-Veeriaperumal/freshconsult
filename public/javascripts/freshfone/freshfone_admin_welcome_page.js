(function ($) {
  "use strict";
  var $freshfone_trial_subscription = $('#frehsfone_trial_request');
  $freshfone_trial_subscription.on('click', function(){
    var self = this;
    $(self).addClass('disabled');
    App.Kissmetrics.push_event(freshfone.admin_metrics.TRY_PHONE, freshfone.current_user_details);
  });
  $(window).on('load', function(){
    App.Kissmetrics.push_event(
      freshfone.admin_metrics.ADMIN_PHONE_PAGE_LOADED || freshfone.admin_metrics.ADMIN_PHONE_PAGE_LOADED_IN_TRIAL,
      freshfone.current_user_details);
  });
}(jQuery));