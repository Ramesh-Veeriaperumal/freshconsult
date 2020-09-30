(function ($) {

  "use strict";

  window.onload = function(){
    var setting_url = '/api/_/freshcaller/settings';
    var refreshToken = function(responseFunction){
      $.get(setting_url).done(responseFunction);
    };
    $.when(
      $.getScript(freshcaller.widgetLoaderUrl)
    ).done(function () {
      $.get(setting_url).done(function(response){
        window.freshcallerWidget = new window.FreshcallerWidget({
          widgetUrl: freshcaller.widgetUrl, productName: 'freshdesk',
          freshidEnabled: response.freshcaller_settings.freshid_enabled, token: response.freshcaller_settings.token,
          refreshToken: refreshToken,
          styleOptions: { left: ' left: -10px;', zindex: ' z-index: 9;' }
        });
      });
    });
    window.addEventListener('freshcaller-widget-ready', function(){
      $('#widget-loader').addClass('hide');
      $('.freshcaller_widget .ficon-ff-phone').removeClass('hide');
    });
    $("body").on("click", "#fcall-widget-button", function(){
      if($(this).children('#widget-loader').hasClass('hide')){
        $(this).toggleClass('active');
        // hari: dirty hack......
        if($(this).hasClass('active')) {
          window.fcAgentWidget.move({
            leftOffset: $('#fc-widget').width()
          });
        } else {
          window.fcAgentWidget.move({
            leftOffset: '70'
          });
        }
      }
    });
  };
})(jQuery);