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
      App.Solutions.SearchConfig.onVisit();
    },
    
    onLeave: function (data) {
      $('body').off('.folders_articles');
      App.Solutions.SearchConfig.onLeave();
    },

    initialData: function () {
      this.data.totalElements = $(".item_ids_checkbox").length;
    },

    selectedElementsCount: function () {
      var count = $(".item_ids_checkbox:checked").length;
      this.toggleSelectAll(this.data.totalElements === count);
      this.toggleActionsClass(!(count > 0));
      this.getSelectedElementIds();
    },

    getSelectedElementIds: function () {
      this.data.selectedElementIds = $('.item_ids_checkbox:checked').map(function(_, el) {
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
        $("#change_author").addClass('hide');
      }
    },

    toggleSelectAll: function (checked) {
      $("#fa_item-select-all").attr('checked', checked);
    },

    bindHandlers: function () {
      var $this = this;


      //generic for folder listing and article listing page
      $('body').on('change.folders_articles', '.item_ids_checkbox', function () {
        $this.selectedElementsCount();
      });

      $('body').on('change.folders_articles', '#fa_item-select-all', function () {
        $this.allSelectAction(this.checked);
      });
      //end

      //binding for visible to
      $('body').on('click.folders_articles', '.visibility-selector', function () {
        $this.visibleToSelection($(this).data());
      });

      //binding for folders move to
      $('#folder-bulk-action #move_to').on('change.folders_articles', function() {
        console.log(this.value);
        console.log($this.data.selectedElementIds);
        $this.bulk_action($this, 'folders', 'move_to', this.value);
      });

      //binding for articles move to
      $('#article-bulk-action #move_to').on('change.folders_articles', function() {
        console.log(this.value);
        console.log($this.data.selectedElementIds);
        $this.bulk_action($this, 'articles', 'move_to', this.value);
      });

      //binding for change author
      $('#change_author').on('change.folders_articles', function () {
        console.log(this.value);
        console.log($this.data.selectedElementIds);
        $this.bulk_action($this, 'articles', 'change_author', this.value);
      });

      //bindings for undo
      $('body').on('click.folders_articles', '#folders_undo_bulk', function () {
        $this.undo_bulk_action($(this), "folders");
      });

      $('body').on('click.folders_articles', '#articles_undo_bulk', function () {
        $this.undo_bulk_action($(this), "articles");
      });

      //folder visibility
      $('body').on('change.folders_articles', '#solution_folder_visibility', function () {
        $this.show_hide_customers();
      });
    },

    allSelectAction: function (checked) {
      $(".item_ids_checkbox").attr('checked', checked);
      this.selectedElementsCount();
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
      this.submitData.folderIds = this.data.selectedElementIds;
    },

    visibleToSubmit: function () {
      var $this = this;
      this.preVisibleToSubmitActions();
      this.loadingAnimation();


      console.log("Visibility : ");
      console.log(this.submitData);
      

      $.ajax({
        url: $this.data.visibleToUrl,
        type: 'PUT',
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

    },

    bulk_action: function (obj, list_name, action_name, parentId) {
      $.ajax({
        url: "/solution/" + list_name + "/" + action_name,
        type: 'PUT',
        dataType: 'script',
        data: {
          parent_id: parentId,
          items: obj.data.selectedElementIds
        },
        success: function () {
          console.log('success');
         }
       });
      jQuery("#" + action_name).select2('val', '');
    },

    undo_bulk_action: function (obj, list_name) {
      $('#noticeajax').hide();
      $.ajax({
        url: "/solution/" + list_name + "/move_back",
        type: 'PUT',
        dataType: 'script',
        data: {
          parent_id: obj.data('parent-id'),
          items: obj.data('items')
        },
        success: function () {
          console.log('success');
         }
       });
    },

    removeElementsAfterMoveTo: function () {
      $('li:has(input[type=checkbox]:checked)').remove();
    },

    show_hide_customers: function () {
      var visiblity = $('#solution_folder_visibility').val();        
      if (visiblity == 4) {
        $('.company_folders').show();
      }
      else {
        $('#customers_filter').val("");
        $("#customers_filter").trigger("liszt:updated");
        $('.company_folders').hide();
      }
    }
  };
}(window.jQuery));