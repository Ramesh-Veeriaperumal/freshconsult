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
      $('body').off('.folders');
    },

    initialData: function () {
      this.data.totalFolders = $(".folder_ids_checkbox").length;
    },

    selectedFoldersCount: function () {
      var count = $(".folder_ids_checkbox:checked").length;
      this.toggleSelectAll(this.data.totalFolders === count);
      this.toggleActionsClass(!(count > 0));
      this.getSelectedFolderIds();
    },

    getSelectedFolderIds: function () {
      this.data.selectedFolderIds = $('.folder_ids_checkbox:checked').map(function(_, el) {
        return $(el).val();
      }).get();
    },

    toggleActionsClass: function (checked) {
      $("#folder-bulk-action").toggleClass('faded', checked);
      if ( checked == false) {
        $(".folder-bulk-btns").removeClass('disabled');
      } else {
        $(".folder-bulk-btns").addClass('disabled');
        $("#move_to").addClass('hide');
        $("#visible_to").addClass('hide'); 
      }
    },

    toggleSelectAll: function (checked) {
      $("#folder-select-all").attr('checked', checked);
    },

    bindHandlers: function () {
      var $this = this;

      $('body').on('change.folders', '.folder_ids_checkbox', function () {
        $this.selectedFoldersCount();
      });

      $('body').on('change.folders', '#folder-select-all', function () {
        console.log(this.checked);
        $this.allSelectAction(this.checked);
      });

    },

    allSelectAction: function (checked) {
      $(".folder_ids_checkbox").attr('checked', checked);
      this.toggleActionsClass(!checked);
    }

  };
}(window.jQuery));