/*jslint browser: true, devel: true */
/*global  App, moment, highlight_code, Fjax, invokeRedactor, invokeEditor */

window.App = window.App || {};
(function ($) {
  "use strict";

  App.Solutions.Article = {
    
    data: {},

    STRINGS: {},

    articleTags: {},

    autoSave: null,

    onVisit: function (data) {
      if (App.namespace === "solution/articles/new" || App.namespace === "solution/articles/create" || App.namespace === "solution/articles/edit") {
        $('#sticky_redactor_toolbar').removeClass('hide');

        if($('#solution_article_description').data('newEditor')) {
          invokeEditor('solution_article_description', 'solution');
        } else {
          invokeRedactor('solution_article_description', 'solution');
        }

        this.eventsForNewPage();
      } else {
        this.eventsForShowPage();
      }
      this.dummyActionButtonTriggers();
      this.formatTranslationDropdown();
      this.showVersionDropdown();
      this.versionSelection();
    },
    
    onLeave: function (data) {
      $('body').off('.articles');
      $(document).off('.articles');
      $(window).off('.articles');
      if (this.autoSave) {
        this.autoSave.stopSaving();
        this.autoSave = null;
      }
    },

    eventsForNewPage: function () {
      this.handleEdit();
      this.bindPropertiesToggle();
      this.formatSeoMeta();
      this.seoCharCounter();
      this.unsavedContentNotif();
      this.formValidate();
      this.toggleShowMaster();
      this.bindForShowMaster();
    },

    eventsForShowPage: function () {
      this.resetData();
      this.setDataFromPage();
      this.showPageBindings();
      this.handleEdit();
      this.formValidate();
      this.highlightCode();
    }

  };
}(window.jQuery));