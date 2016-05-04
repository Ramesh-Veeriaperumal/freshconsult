/*jslint browser: true, devel: true */
/*global  App, nativePlaceholderSupport */

window.App = window.App || {};
(function ($) {
  "use strict";

  App.Solutions = {
    current_module: '',

    translationDropdownOpts: {
      dropdownAutoWidth: 'true',
      dropdownCssClass: 'add-translation-dropdown',
      minimumResultsForSearch: 7
    },

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
      this.configurePlaceholder();
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
      $('body').on('change.solutionHome', '#solution_folder_meta_visibility', App.Solutions.Folder.setCompanyVisibility);
      $('body').on('click.solutionHome', '.modal-footer [data-dismiss="modal"]', this.resetFormOnCancel);
    },

    unBindHandlers: function () {
      $('body').off('.solutionHome');
    },

    configurePlaceholder: function () {
      if (!nativePlaceholderSupport()) {
        $('.solutions input.solution-placeholder').placeholder();
      }
    },

    formatLangOptions: function (state) {
      var originalOption = state.element, outdated;
      return "<span class='language_symbol " + $(originalOption).data('state') + "'>" + "<span class='language_name'>" + $(originalOption).data('code') + "</span></span>" + "<span class='language_label'>" + state.text + "</span>";
    },

    resetFormOnCancel: function (e) {
      var form = $('#' + e.target.id).parents('.modal').find('form');
      App.Solutions.resetModalForm(form);
    },

    resetModalForm: function (form) {
      form.resetForm();
      form.find('.select2').trigger('change');
      form.find('.error_messages').empty();
      if (form.find('.company_folders').length > 0) {
        var customers_input = form.find('.autocomplete_filter [type="hidden"]');
        customers_input.select2('val', customers_input.data().initialValue);
      }
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
