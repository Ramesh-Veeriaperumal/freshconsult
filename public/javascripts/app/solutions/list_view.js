/*jslint browser: true, devel: true */
/*global  App, moment, highlight_code, Fjax */

window.App = window.App || {};
(function ($) {
	"use strict";

  App.Solutions.Folder = {
    
    data: {},
    submitData: {},
    COMPANY_VISIBILITY: 4,

    onVisit: function (data) {
      this.initialData();
      this.bindHandlers();
      this.removeCurrentFolder();
    },
    
    onLeave: function (data) {
      $('body').off('.folders_articles');
    },

    initialData: function () {
      this.data.totalElements = $(".item_ids_checkbox").length;
    },

    selectedElementsCount: function () {
      var count = $(".item_ids_checkbox:checked").length;
      this.toggleSelectAll(this.data.totalElements === count);
      this.toggleActionsClass(count <= 0);
      this.getSelectedElementIds();
    },

    getSelectedElementIds: function () {
      this.data.selectedElementIds = $('.item_ids_checkbox:checked').map(function (i, el) {
        return $(el).val();
      }).get();
    },

    toggleActionsClass: function (checked) {
      $("#folder-bulk-action, #article-bulk-action").toggleClass('faded', checked);
      if (checked === false) {
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
      $('body').on('click.folders_articles', '.visibility-selector', function (ev) {
        ev.preventDefault();
        $this.visibleToSelection($(this).data());
      });

      $('body').on('click.folders_articles', '.visible-to-btn', function () {
        if ($this.submitData.visibility === 4) {
          $('.company_folders .select2-search-field input').focus();
        }
      });

      $('body').on('reorder.folders_articles', function () {
        App.Solutions.NavMenu.reload();
      });

      $('body').on('change.folders_articles', '#move_to, #change_author', function () {
        var el = $(this);
        $this.bulk_action($this, el.data('action-on'), el.data('action'), this.value);
      });
      
      $('body').on('click.folders_articles', '#folders_undo_bulk, #articles_undo_bulk', function () {
        var el = $(this);
        $this.undo_bulk_action(el,el.data('action-on'));
      });

      $('#move_to').on('select2-open', function () {
        if ($('#visible_to').is(':visible')) {
          $this.toggleVisibleTo(false);
        }
        hideActiveMenu();
      });

      $("body").on('click.folders_articles', function (e) {
        var container =  $('.visible-to-btn');
        if (!container.is(e.target) && container.has(e.target).length === 0) {
            $this.toggleVisibleTo(false);
        } else {
          if ($('#visible_to').is(':visible')) {
            $this.toggleVisibleTo(true);
          } else {
            $this.toggleVisibleTo(false);
          }
        }
      });

      focusFirstModalElement('folders_articles');
    },

    toggleVisibleTo: function (flag) {
      $('.visible-to-btn').toggleClass('highlight-border', flag);
      $('.visible-to-btn .bulk-action-btns').toggleClass('drop-right', !flag).toggleClass('visible-to-selected',flag);
    },

    removeCurrentFolder: function () {
      $('#article-bulk-action #move_to option').each(function (i, x) {
				if (x.value === $('h2').attr('folder-id')) {
					$(x).remove();
				}
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
      if (data.visibility === this.COMPANY_VISIBILITY) {
        this.toggleCompanyClass(true);
        this.eventsForCompanySelect();
        $('.company_folders .select2-search-field input').focus();
      } else {
        this.visibleToSubmit();
        this.toggleCompanyClass(false);
      }
    },

    toggleCompanyClass: function (flag) {
      $(".right-select-companies").toggleClass('hide', !flag);
      $('.select_companies').toggleClass('selected', flag);
    },

    eventsForCompanySelect: function () {
      var $this = this;
      $('body').off('.select_company');

      $('body').on('click.folders_articles.select_company', '#company-submit', function () {
        event.preventDefault();
        $this.visibleToSubmit();
      });
    },

    hideFdMenu: function () {
      this.toggleCompanyClass(false);
      $("#visible_to").hide();
      $(".bulk-action-btns[menuid='#visible_to']").removeClass('selected');
    },

    getCompanyData: function () {
      if (this.submitData.visibility === this.COMPANY_VISIBILITY) {
        this.submitData.companies = $("#change_folder_customers_filter").val();
        this.submitData.addToExisting = $(".right-select-companies .add-to-existing:checked").val();
      }
      this.submitData.folderIds = this.data.selectedElementIds;
      return this.submitData;
    },

    visibleToSubmit: function () {
      var $this = this;
      this.hideFdMenu();
      this.loadingAnimation();

      $.ajax({
        url: $this.data.visibleToUrl,
        type: 'PUT',
        data: $this.getCompanyData(),
        dataType: "script"
      });
    },

    onSaveSuccess: function () {
      this.initialData();
      console.log("success");
    },

    onSaveError: function () {
      console.log("error");
    },

    loadingAnimation: function () {

    },

    bulk_action: function (obj, list_name, action_name, parentId) {
      var $this = this;
      $.ajax({
        url: "/solution/" + list_name + "/" + action_name,
        type: 'PUT',
        dataType: 'script',
        data: {
          parent_id: parentId,
          items: obj.data.selectedElementIds
        },
        success: function () {
          App.Solutions.NavMenu.reload();
          $this.initialData();
          console.log('success');
        }
      });
      $("#" + action_name).select2('val', '');
    },

    undo_bulk_action: function (obj, list_name) {
      var $this = this;
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
          App.Solutions.NavMenu.reload();
          $this.initialData();
          $.proxy(this.onSaveSuccess, this);
        },
        error: $.proxy(this.onSaveError, this)
      });
    },

    removeElementsAfterMoveTo: function () {
      $('li:has(input[type=checkbox]:checked)').not('.lf-item').remove();
    },
    
    hideSelectAll: function () {
      if ($('#fa_item-select-all:checked').size() > 0) {
        $("#fa_item-select-all").attr('checked', false);
      }
    },

    setCompanyVisibility: function () {
      console.log('setting company visiblity');
      var visiblity = $('#solution_folder_visibility').val();
      if (parseInt(visiblity, 10) === 4) {
        $('.company_folders').show();
      } else {
        $('#customers_filter').val("");
        $("#customers_filter").trigger("liszt:updated");
        $('.company_folders').hide();
      }
    }
  };
}(window.jQuery));