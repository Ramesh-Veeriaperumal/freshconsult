(function ($) {
  "use strict";
  var $container = $('body'),
      freshfone_feature_request_div = '#freshfone_feature_request',
      freshfone_feature_request_div_widget = '#freshfone_feature_request_widget',
      freshfone_flash_div = '#ff_feature_request',
      fromWidget = 'iswidget',
      freshfone_flash_div_widget = '#ff_feature_request_widget';

  $container.on('click', freshfone_feature_request_div+ " , " +
                freshfone_feature_request_div_widget, function () {
    if(freshfone.activationRequested)
      return;
    var self = this;
    beforeActivation(self);
    $.ajax({
      url: '/admin/phone/request_freshfone_feature',
      type: "post",
      success: function () {
        requestSuccess(self);
      },
      error: function () {
        requestError(self);
      }
    });
  });

  function beforeActivation(ele){
    setForWidget(ele);
    $(ele).addClass('disabled');
    $(".small_note").hide(); // for without onboarding feature
  }

  function setForWidget(ele){
    if($(ele).data(fromWidget))
      freshfone_flash_div = freshfone_flash_div_widget;
  }

  function requestSuccess(ele){
    hideActivate(ele);
    hideParentDiv(ele);
    removeTarget(ele);
    if (!$(freshfone_flash_div).data('afterRequestContent'))
      $(freshfone_flash_div).html(freshfone.request_success_message);
    $(freshfone_flash_div).show();
    freshfone.activationRequested = true;
  }

  function requestError(ele){
    $(ele).button('reset');
    $(freshfone_flash_div)
      .html(freshfone.request_error_message)
      .removeClass('hide').show();
  }
  function hideActivate(ele){
    $(ele).removeClass('show').addClass('hide');
  }
  function hideParentDiv(ele){
    if($(ele).parent().data('removable'))
      $(ele).parent().removeClass('show').addClass('hide');
  }
  function removeTarget(ele){
    if($(ele).data('removeTarget'))
      $("."+$(ele).data('removeTarget')).remove();
  }
})(jQuery);