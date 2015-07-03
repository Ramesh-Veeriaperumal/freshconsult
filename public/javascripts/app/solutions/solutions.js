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
      $('body').on('change.solutionHome', '#solution_folder_visibility', this.setCompanyVisibility);
    },

    unBindHandlers: function () {
      $('body').off('.solutionHome');
    },

    setCompanyVisibility: function () {
      var visiblity = $('#solution_folder_visibility').val();
      if (parseInt(visiblity,10) === 4) {
        $('.company_folders').show();
      } else {
        $('#customers_filter').val("");
        $("#customers_filter").trigger("liszt:updated");
        $('.company_folders').hide();
      }
    },

    onLeave: function (data) {
      if (this.current_module !== '') {
        this[this.current_module].onLeave();
        this.current_module = '';
      }
      App.Solutions.Reorder.leave();
      App.Solutions.NavMenu.leave();
      this.unBindHandlers();
    }
  };

}(window.jQuery));
