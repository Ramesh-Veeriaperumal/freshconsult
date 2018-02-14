(function ($) {

  "use strict";

  window.onload = function(){
    $.when(
      $.getScript(freshcaller.widgetLoaderUrl)
    ).done(function () {
      $.get('/api/_/freshcaller/settings').done(function(response){
        window.freshcallerWidget = new window.FreshcallerWidget({
          widgetUrl: freshcaller.widgetUrl, productName: 'freshdesk',
          freshidEnabled: response.freshcaller_settings.freshid_enabled, token: response.freshcaller_settings.token,
          styleOptions: { left: ' left: -10px;', zindex: ' z-index: 9;' }
        });
      });
    });
    window.addEventListener('freshcaller-widget-ready', function(){
      $('#widget-loader').addClass('hide');
      $('.freshfone_widget .ficon-ff-phone').removeClass('hide');
    });
    $("body").on("click", "#fcall-widget-button", function(){
      if($(this).children('#widget-loader').hasClass('hide')){
        $(this).toggleClass('active');
      }
    });
  };
})(jQuery);