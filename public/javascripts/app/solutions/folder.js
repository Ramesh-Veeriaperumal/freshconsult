/*jslint browser: true, devel: true */
/*global  App, moment, highlight_code, Fjax */

window.App = window.App || {};
(function ($) {
  "use strict";

  App.Solutions.Folder = {
    
    data: {},

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
      this.data.selectedFolderIds = $('.item_ids_checkbox:checked').map(function(_, el) {
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
      this.toggleActionsClass(!checked);
    },

    visibleToSelection: function (data) {
      this.data.visibility = data.visibility;
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
      if ( this.data.visibility == 4 ) {
        this.data.companies = $("#customers_filter").val();
        this.data.addToExisting = $(".right-select-companies .add-to-existing:checked").val();
      }
    },

    visibleToSubmit: function () {
      this.preVisibleToSubmitActions();
      console.log(" Visibility : "+ this.data.visibility);
      if (this.data.visibility == 4 ) {
        console.log(" Companies : "+ this.data.companies);
        console.log(" Add To Existing : "+ this.data.addToExisting); 
      }
    }


  };
}(window.jQuery));