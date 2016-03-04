/*jslint browser: true */
/*global  App, alert */

window.App = window.App || {};
window.App.Admin = window.App.Admin || {};
(function ($) {
  "use strict";

  App.Admin.LanguageSettings = {

    onVisit: function () {
      this.bindHandlers();
    },
    
    bindHandlers: function () {
      $("body").on('submit.language_settings', '#manage_languages_form', this.validateLanguage);
      this.portalLanguageConfig();
    },

    validateLanguage: function (ev) {
      if (($.inArray($("#account_main_portal_attributes_language").val(), $("#account_account_additional_settings_attributes_supported_languages").val())) !== -1) {
        ev.preventDefault();
        alert(App.Admin.LanguageSettings.INVALID_LANGUAGE_ALERT);
      }
    },

    portalLanguageConfig: function () {
      var $this = this;
      $('#account_supported_languages').on('change.language_settings', function () {
				$('#portal_supported_languages').select2({
					multiple: true,
					data: $this.supportedPortalLanguages()
				});
      }).trigger('change');
      $('#portal_supported_languages').select2('val', $('#portal_supported_languages').data('portalLanguages')).trigger('change');
    },

    supportedPortalLanguages: function () {
      var supportedLanguages = $('#account_supported_languages :selected'),
				portalLanguages = [],
				language;
      $.each(supportedLanguages, function (i, language) {
        portalLanguages.push({ id: language.value, text: language.text });
      });
      return portalLanguages;
    },

    onLeave: function () {
      $('body').off('.language_settings');
    }

  };
}(window.jQuery));
