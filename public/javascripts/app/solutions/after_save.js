/*jslint browser: true, devel: true */
/*global  App, $H, delay */

window.App = window.App || {};
window.App.Solutions = window.App.Solutions || {};
(function ($) {
  "use strict";
  App.Solutions.AfterSave = {
    
    currentCategory: null,
    currentPortal: null,

    onVisit: function () {
      this.bindHandlers();
    },

    setCurrentObject: function (obj) {
      switch (App.namespace) {
      case "solution/categories/show":
        this.currentCategory = obj;
        break;
      case "solution/categories/all_categories":
        this.currentPortal = obj;
        break;
      }
    },

    hide: function (modal) {
      jQuery(modal).modal('hide');
    },

    bindHandlers: function () {
      
    },

    onLeave: function () {
      $('body').off('.after-save');
    }
  };
}(window.jQuery));