/*jslint browser: true */
/*global  App, alert */

window.App = window.App || {};
window.App.Admin = window.App.Admin || {};
(function ($) {
  "use strict";

  App.Admin.LanguageSettings = {

    langTemplate: "<div class=\"lang-selected-option\"> \
                    <div class=\"span9\"> \
                      <div class=\"remove-language\" data-lang-code=\"${langCode}\"> \
                        <span class=\"rounded-minus-icon\"> </span> \
                        <span class=\"lang-name ml5\"> ${langName} </span>\
                      </div>\
                    </div>\
                    <div class=\"span3\"> \
                      <div class=\"portal-language-visibility mr20 ${activeClass}\" data-lang-code=\"${langCode}\" data-visible-in-portal=\"${visibility}\">\
                        <span class=\"portal-language-text mr5\"> ${visibleText} </span>\
                        <i class=\"ficon-eye fsize-20\"> </i>\
                        <i class=\"ficon-eye-disabled fsize-20\"> </i>\
                      </div>\
                    </div>\
                  </div>",

    onVisit: function () {
      this.initialize();
      this.bindHandlers();
    },

    initialize: function () {
      this.portalLangEl = $('#portal_supported_languages');
      this.supportedLangEl = $("#account_supported_languages");
      this.portalLanguageConfig();
    },

    portalLanguageConfig: function () {
      var $this = this;

      // Initialize Select2 in the beginining
      $('#account_supported_languages').select2({
        formatSelection: function () {return '';},
        allowClear: true
      });
      
      // Generate the already selected options html
      var initialSelectedOptions = this.supportedLangEl.get(0).selectedOptions || [];
      for (var key = 0; key < initialSelectedOptions.length ; key++) {
        $this.addSingleLanguage(initialSelectedOptions[key]);
      };

    },

    bindHandlers: function () {
      $("body").on('submit.language_settings', '#manage_languages_form', this.validateLanguage);
      $("body").on('click.language_settings', '.remove-language', $.proxy(this.removeLanguage, this));
      $("body").on('click.language_settings', '.portal-language-visibility', $.proxy(this.portalVisibilityToggle, this));

      //The event 'select2-selecting' is only for 3.5.x versions of select2, the event is differnt in newer version
      $('#account_supported_languages').on('select2-selecting', $.proxy(function (e) {
        this.addSingleLanguage(e.object.element);  
      }, this));
    },

    addSingleLanguage: function (el) {
      var langCode = $(el).val();
      var portalLangs = this.portalLangEl.val() || [];
      var visible = (portalLangs.indexOf(langCode) != -1);

      var tempateVariables = {
        langName: $(el).text(),
        langCode: langCode
      };
      tempateVariables['visibleText'] = (visible ? App.Admin.LanguageSettings.msgPortalVisible : App.Admin.LanguageSettings.msgPortalHidden);
      tempateVariables['activeClass'] = (visible ? "active" : "");
      tempateVariables['visibility'] = visible;

      $.tmpl(this.langTemplate, tempateVariables).prependTo('#manage_languages_form .selected-languages').animateHighlight();
    },
    
    validateLanguage: function (ev) {
      if (($.inArray($("#account_main_portal_attributes_language").val(), $("#account_account_additional_settings_attributes_supported_languages").val())) !== -1) {
        ev.preventDefault();
        alert(App.Admin.LanguageSettings.INVALID_LANGUAGE_ALERT);
      }
    },

    removeLanguage: function (e) {
      var langCode = e.target.dataset.langCode || e.target.parentElement.dataset.langCode;
      
      var supportedLangs = this.supportedLangEl.val() || [];
      var newValues = this.removeAndUpdateValue(this.supportedLangEl, supportedLangs, langCode);
      this.supportedLangEl.select2('val', newValues).trigger('change');

      var portalLanguages = this.portalLangEl.val() || [];
      this.removeAndUpdateValue(this.portalLangEl, portalLanguages, langCode);

      $(e.target).closest('.lang-selected-option').remove();
    },

    removeAndUpdateValue: function (el, arr, val) {
      if (arr.indexOf(val) > -1) {
        arr.splice(arr.indexOf(val), 1);
        el.val(arr);
      }
      return arr;
    },

    portalVisibilityToggle: function (e) {
      var targetEl = e.target.parentElement;
      if (e.target.classList.contains("portal-language-visibility")) {
        var targetEl = e.target;
      }

      var langCode = targetEl.dataset.langCode;
      var portalLanguages = this.portalLangEl.val() || [];
      var visibility = $(targetEl).data('visibleInPortal');
      
      if (visibility === "true" || visibility === true) {
        this.removeAndUpdateValue(this.portalLangEl, portalLanguages, langCode);
        this.changeVisibilityState(targetEl, App.Admin.LanguageSettings.msgPortalHidden, visibility);
      } else {
        portalLanguages.push(langCode);
        this.portalLangEl.val(portalLanguages);
        this.changeVisibilityState(targetEl, App.Admin.LanguageSettings.msgPortalVisible, visibility);
      }
    },

    changeVisibilityState: function (el, textMsg, visible) {
      $(el).data('visibleInPortal', !visible);
      $(el).toggleClass('active', !visible);
      $(el).find('.portal-language-text').html(textMsg);
    },

    onLeave: function () {
      $('body').off('.language_settings');
    }

  };
}(window.jQuery));
