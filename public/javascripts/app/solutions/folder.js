/*jslint browser: true, devel: true */
/*global  App, moment, highlight_code, Fjax */

window.App = window.App || {};
(function ($) {
  "use strict";

  App.Solutions.Folder = {
    
    data: {},
    submitData: {},

    onVisit: function (data) {
      console.log("Loaded the folder.js");
      this.initialData();
      this.bindHandlers();
    },
    
    onLeave: function (data) {
      $('body').off('.folders_articles');
    },

    initialData: function () {
      this.data.totalFolders = $(".item_ids_checkbox").length;
    },

    selectedFoldersCount: function () {
      var count = $(".item_ids_checkbox:checked").length;
      this.toggleSelectAll(this.data.totalFolders === count);
      this.toggleActionsClass(!(count > 0));
      this.getSelectedFolderIds();
    },

    getSelectedFolderIds: function () {
      this.data.folderIds = $('.item_ids_checkbox:checked').map(function(_, el) {
        return $(el).val();
      }).get();
    },

    toggleActionsClass: function (checked) {
      $("#folder-bulk-action, #article-bulk-action").toggleClass('faded', checked);
      if ( checked == false) {
        $(".bulk-action-btns").removeClass('disabled');
      } else {
        $(".bulk-action-btns").addClass('disabled');
        $("#move_to").addClass('hide');
        $("#visible_to").addClass('hide'); 
      }
    },

    toggleSelectAll: function (checked) {
      $("#fa_item-select-all").attr('checked', checked);
    },

    bindHandlers: function () {
      var $this = this;


      //generic for folder listing and article listing page
      $('body').on('change.folders_articles', '.item_ids_checkbox', function () {
        $this.selectedFoldersCount();
      });

      $('body').on('change.folders_articles', '#fa_item-select-all', function () {
        $this.allSelectAction(this.checked);
      });
      //end

      //binding for visible to
      $('body').on('click.folders_articles', '.visibility-selector', function () {
        $this.visibleToSelection($(this).data());
      });

    },

    allSelectAction: function (checked) {
      $(".item_ids_checkbox").attr('checked', checked);
      this.selectedFoldersCount();
    },

    visibleToSelection: function (data) {
      this.submitData = {};
      this.submitData.visibility = data.visibility;
      this.data.visibleToUrl = data.url;
      if ( data.visibility === 4) {
        this.toggleCompanyClass(true);
        this.eventsForCompanySelect();
      } else {
        this.visibleToSubmit();
        this.toggleCompanyClass(false);
      }
    },

    toggleCompanyClass: function (flag) {
      $(".right-select-companies").toggleClass('hide', !flag);
    },

    eventsForCompanySelect: function () {
      var $this = this;
      $('body').off('.select_company');
      
      $('body').on('click.folders_articles.select_company', '#company-cancel', function () {
        $this.hideFdMenu(false);
      });


      $('body').on('click.folders_articles.select_company', '#company-submit', function () {
        event.preventDefault();
        $this.visibleToSubmit();
      });
    },

    preVisibleToSubmitActions: function () {
      this.hideFdMenu();
      this.getCompanyData();
    },

    hideFdMenu: function () {
      this.toggleCompanyClass(false);
      $("#visible_to").css('display', 'none');
      $(".bulk-action-btns[menuid='#visible_to']").removeClass('selected');
    },

    getCompanyData: function () {
      if ( this.submitData.visibility == 4 ) {
        this.submitData.companies = $("#customers_filter").val();
        this.submitData.addToExisting = $(".right-select-companies .add-to-existing:checked").val();
      }
      this.submitData.folderIds = this.data.folderIds;
    },

    visibleToSubmit: function () {
      var $this = this;
      this.preVisibleToSubmitActions();
      this.loadingAnimation();


      console.log("Visibility : ");
      console.log(this.submitData);
      

      $.ajax({
        url: $this.data.visibleToUrl,
        type: 'POST',
        data: this.submitData,
        dataType: "script",
        success: $.proxy(this.onSaveSuccess, this),
        error: $.proxy(this.onSaveError, this)
      });
    },

    onSaveSuccess: function () {
      console.log("success");
    },

    onSaveError: function () {
      console.log("error");
    },

    loadingAnimation: function () {

    }


  };
}(window.jQuery));