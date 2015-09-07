/*jslint browser: true, devel: true */
/*global  App */

window.App = window.App || {};
(function ($) {
  "use strict";

  App.Solutions = {
    current_module: '',

    onFirstVisit: function (data) {
      this.onVisit(data);
    },

    onVisit: function (data) {
      this.setSubModule();
      if (this.current_module !== '') {
        this[this.current_module].onVisit();
      }
      App.Solutions.Reorder.start();
			App.Solutions.NavMenu.start();
      App.Solutions.SearchConfig.onVisit();
      this.bindHandlers();
    },

    setSubModule: function () {
      switch (App.namespace) {
      case "solution/manage":
        this.current_module = 'Manage';
        break;
      case "solution/articles/edit":
      case "solution/articles/show":
      case "solution/articles/new":
      case "solution/articles/create":
      case "solution/articles/update":
        this.current_module = 'Article';
        break;
      case "solution/categories/show":
      case "solution/folders/show":
      case "solution/folders/new":
        this.current_module = 'Folder';
        break;
      case "solution/categories/index":
        this.current_module = 'Category';
        break;
      }

    },

    bindHandlers: function () {
      $('body').on('change.solutionHome', '#solution_folder_visibility', App.Solutions.Folder.setCompanyVisibility);
    },

    unBindHandlers: function () {
      $('body').off('.solutionHome');
    },

    onLeave: function (data) {
      if (this.current_module !== '') {
        this[this.current_module].onLeave();
        this.current_module = '';
      }
      App.Solutions.Reorder.leave();
      App.Solutions.NavMenu.leave();
      App.Solutions.SearchConfig.onLeave();
      this.unBindHandlers();
    }
  };

}(window.jQuery));
