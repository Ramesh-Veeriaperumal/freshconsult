/*jslint browser: true es5: true */
/*global  App, alert */

window.App = window.App || {};
window.App.Admin = window.App.Admin || {};
(function ($) {
  "use strict";

  App.Admin.LanguageSettings = {

    langTemplate: "<div class='lang-selected-option'> \
                    <div class='span9'> \
                      <div class='remove-language'> \
                        <span class='rounded-minus-icon remove-icon' data-lang-code='${langCode}'> </span> \
                        <span class='lang-name ml5'> ${langName} </span>\
                      </div>\
                    </div>\
                    <div class='span3'> \
                      <div class='portal-language-visibility mr10 ${activeClass}'>\
                        <span class='portal-language-text pull-left mr8 mt2'> ${visibleText} </span>\
                        <i class='ficon-eye fsize-20'> </i>\
                        <i class='ficon-eye-disabled fsize-20'> </i>\
                        <input type='hidden' name='account[account_additional_settings_attributes][additional_settings][portal_languages][]' \
                          value='${langCode}' ${disabled} />\
                      </div>\
                    </div>\
                  </div>",

    onVisit: function () {
      this.initialize();
      this.bindHandlers();
    },

    initialize: function () {
      this.supportedLangEl = $("#account_supported_languages");
      this.portalLanguages = $('#manage_languages_form').data().portalLanguages || [];
      this.portalLanguageConfig();
    },

    portalLanguageConfig: function () {
      var $this = this, initialSelectedOptions, key, langCode, visible;

      // Initialize Select2 in the beginining
      $('#account_supported_languages').select2({
        formatSelection: function () {return ''; },
        allowClear: true
      });
      
      // Generate the already selected options html
      initialSelectedOptions = this.supportedLangEl.get(0).selectedOptions || [];
      for (key = 0; key < initialSelectedOptions.length; key += 1) {
        langCode = $(initialSelectedOptions[key]).val();
        visible = (this.portalLanguages.indexOf(langCode) !== -1);
        $this.addSingleLanguage(initialSelectedOptions[key], visible, false);
      }
    },

    bindHandlers: function () {
      $("body").on('submit.language_settings', '#manage_languages_form', this.validateLanguage);
      $("body").on('click.language_settings', '.remove-language .remove-icon', this.removeLanguage);
      $("body").on('click.language_settings', '.portal-language-visibility', this.portalVisibilityToggle);

      //The event 'select2-selecting' is only for 3.5.x versions of select2, the event is differnt in newer version
      $('#account_supported_languages').on('select2-selecting', $.proxy(function (e) {
        this.addSingleLanguage(e.object.element, false, true);
      }, this));
    },

    addSingleLanguage: function (el, visible, newAddition) {
      var langCode = $(el).val(),
				tempateVariables = {
					langName: $(el).text(),
					langCode: langCode,
					visibleText: (visible ? App.Admin.LanguageSettings.msgPortalVisible : App.Admin.LanguageSettings.msgPortalHidden),
					activeClass: (visible ? "active" : ""),
					disabled: (visible ? '' : 'disabled')
				},
				newLangEl = $.tmpl(this.langTemplate, tempateVariables).prependTo('#manage_languages_form .selected-languages');
      if (newAddition) {
        $(newLangEl).animateHighlight();
      }
    },
    
    validateLanguage: function (ev) {
      if (($.inArray($("#account_main_portal_attributes_language").val(), $("#account_account_additional_settings_attributes_supported_languages").val())) !== -1) {
        ev.preventDefault();
        alert(App.Admin.LanguageSettings.INVALID_LANGUAGE_ALERT);
      }
    },

    removeLanguage: function (e) {
      var langCode = $(this).data().langCode,
				supportedLangEl = $("#account_supported_languages");
      $(supportedLangEl)
        .select2('val', (supportedLangEl.val() || []).reject(function (a) {return a === langCode; }))
        .trigger('change');
      $(this).closest('.lang-selected-option').remove();
    },

    portalVisibilityToggle: function (e) {
      var currentState = $(this).find('input').prop('disabled'),
				textMsg = currentState ? App.Admin.LanguageSettings.msgPortalVisible : App.Admin.LanguageSettings.msgPortalHidden;
      $(this).toggleClass('active', currentState);
      $(this).find('.portal-language-text').html(textMsg);
      $(this).find('input').prop('disabled', !currentState);
    },

    onLeave: function () {
      $('body').off('.language_settings');
    }

  };
}(window.jQuery));
