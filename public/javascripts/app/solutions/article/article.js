/*jslint browser: true, devel: true */
/*global  App, moment, highlight_code, Fjax */

window.App = window.App || {};
(function ($) {
  "use strict";

  App.Solutions.Article = {
    
    data: {},

    STRINGS: {},

    articleTags: {},

    autoSave: null,

    onVisit: function (data) {
      if (App.namespace === "solution/articles/new") {
        this.eventsForNewPage();
      } else {
        this.eventsForShowPage();
      }
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
      this.bindPropertiesToggle();
      this.formatSeoMeta();
      this.setTagSelector();
      this.dummyActionButtonTriggers();
      this.unsavedContentNotif();
      this.formValidate();
    },

    eventsForShowPage: function () {
      this.resetData();
      this.setDataFromPage();
      this.showPageBindings();
      this.handleEdit();
      this.formValidate();
      highlight_code();
    }

  };
}(window.jQuery));