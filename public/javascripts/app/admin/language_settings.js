window.App = window.App || {};
window.App.Admin = window.App.Admin || {};
(function ($) {
  "use strict";

  App.Admin.LanguageSettings = {

    onVisit: function () {
      this.bindHandlers();
    },
    
    bindHandlers: function () {
      var $this = this;
      $( document ).ready(function() {
        $("body").on('submit.language_settings', '#manage_languages_form', $this.validateLanguage);
        $this.portalLanguageConfig();
      });
    },

    validateLanguage: function (ev) {
      var language_flag = $.inArray($("#account_main_portal_attributes_language").val(),
                          $("#account_account_additional_settings_attributes_supported_languages").val());
      if(language_flag != -1 ) {
        ev.preventDefault(); 
        alert(App.Admin.LanguageSettings.INVALID_LANGUAGE_ALERT);
      }
    },

    portalLanguageConfig: function () {
      var $this = this;
      $('#account_supported_languages').select2();
      $('#account_supported_languages').on('change.language_settings', function() {
          var newOptions = $this.supportedPortalLanguages();
          $('#portal_supported_languages').select2({
            multiple: true,
            data: newOptions
          });
      });
      $('#account_supported_languages').trigger('change');
      $('#portal_supported_languages').select2('val', $('#portal_supported_languages').data('portalLanguages'))
                                      .trigger('change');
    },

    supportedPortalLanguages: function() {
      var supportedLanguages = $('#account_supported_languages').select2('data');
      var portalLanguages = [];
      for(var language of supportedLanguages) {  
        portalLanguages.push ({id: language.id, text: language.text});
      }
      return portalLanguages;
    },

    onLeave: function () {
      $('body').off('.language_settings');
    }

  };
}(window.jQuery));
