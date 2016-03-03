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
      this.bindHandlers();
      this.removeCurrentFolder();
    },
    
    onLeave: function (data) {
      $('body').off('.folders_articles');
    },

    totalElements: function () {
      return $(".item_ids_checkbox").length;
    },

    selectedElementsCount: function () {
      var count = $(".item_ids_checkbox:checked").length;
      this.toggleSelectAll(this.totalElements() === count);
      this.toggleActionsClass(count <= 0);
      return count;
    },

    getSelectedElementIds: function () {
      var selectedElementIds = $('.item_ids_checkbox:checked').map(function (i, el) {
        return $(el).val();
      }).get();
      return selectedElementIds;
    },

    toggleActionsClass: function (checked) {
      $("#folder-bulk-action, #article-bulk-action").toggleClass('faded', checked);
      if (checked === false) {
        $(".bulk-action-btns").removeClass('disabled');
        $('.visible-to-btn .bulk-action-btns').attr('disabled', false);
        $('.action-btns-bar').fadeOut(10);
        $('.category-details').addClass('list-selected');
      } else {
        $(".bulk-action-btns").addClass('disabled');
        $("#move_to").addClass('hide');
        $("#visible_to").addClass('hide');
        $("#change_author").addClass('hide');
        $('.visible-to-btn .bulk-action-btns').attr('disabled', true);
        $('.action-btns-bar').fadeIn();
        $('.category-details').removeClass('list-selected');
      }
    },

    toggleSelectAll: function (checked) {
      $("#fa_item-select-all").attr('checked', checked);
    },

    bindHandlers: function () {
      var $this = this;


      //generic for folder listing and article listing page
      $('body').on('change.folders_articles', '.item_ids_checkbox', function () {
        $this.toggleListingSelection(this);
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
        if (App.namespace != "solution/folders/show") {
          App.Solutions.NavMenu.reload();
        }
      });

      $('body').on('change.folders_articles', '#move_to, #change_author', function () {
        var el = $(this);
        if ($this.selectedElementsCount() > 0) {
          $this.bulk_action(el.data('action-on'), el.data('action'), this.value);
        }
      });
      
      $('body').on('click.folders_articles', '#folders_undo_bulk, #articles_undo_bulk', function () {
        var el = $(this);
        $this.undo_bulk_action(el, el.data('action-on'));
      });

      $('#move_to, #change_author').on('select2-open', function () {
        if ($('#visible_to').is(':visible')) {
          $this.toggleVisibleTo(false);
        }
        if ($this.selectedElementsCount() === 0) {
          $('#move_to, #change_author').select2('close');
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

      $("body").on('change.folders_articles', '#solution_folder_meta_solution_category_meta_id', function () {
        $('.check-translations').toggleClass('hide', $(this).data('originalValue') === parseInt($(this).val()));
      });

      $this.bindLanguageBarLinks();
      $("body").on('click.folders_articles', '.confirm-delete' ,function (e) {
        $('.modal').modal('hide');
      });

      focusFirstModalElement('folders_articles');
      $this.initialiseDraftPopover();
    },

    toggleVisibleTo: function (flag) {
      $('.visible-to-btn').toggleClass('highlight-border', flag);
      $('.visible-to-btn .bulk-action-btns').toggleClass('drop-right', !flag).toggleClass('visible-to-selected', flag);
    },

    bindLanguageBarLinks: function () {
      $('#show-link, #hide-link').on('click', function (ev) {
        ev.preventDefault();
        $('.article-details').toggle();
        $('.language-bar').toggle();
        $('#hide-link').toggle();
        $('#show-link').toggle();
      });
    },

    initialiseDraftPopover: function () {
      $('[rel="draft-qtip"]').each(function () {
        $(this).qtip({
          prerender: false,
          position: {
            my: 'top left',
            at: 'bottom left',
            viewport: $(window)
          },
          style: {
            classes: 'draft-qtip',
            tip: {
              mimic: 'center'
            }
          },
          content: function() {
            return $('#' + $(this).data('content-id')).html();
          }
        });
      });
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
      $(".comm-item").toggleClass('active', checked);
      this.selectedElementsCount();
    },

    toggleListingSelection: function (el) {
      $(el).closest('.comm-item').toggleClass('active');
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

      $('body').on('click.folders_articles.select_company', '#company-submit', function (e) {
        e.preventDefault();
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
      this.submitData.folderIds = this.getSelectedElementIds();
      return this.submitData;
    },

    visibleToSubmit: function () {
      var $this = this;
      this.hideFdMenu();

      if($this.selectedElementsCount() > 0) {
        $.ajax({
          url: $this.data.visibleToUrl,
          type: 'PUT',
          data: $this.getCompanyData(),
          dataType: "script"
        });
      }
    },

    bulk_action: function (list_name, action_name, parentId) {
      var $this = this;
      $.ajax({
        url: "/solution/" + list_name + "/" + action_name,
        type: 'PUT',
        dataType: 'script',
        data: {
          parent_id: parentId,
          items: $this.getSelectedElementIds()
        },
        success: function () {
          App.Solutions.NavMenu.reload();
        }
      });
      $("#" + action_name).select2('val', '');
      $('.bulk-action-btns :focus').blur();
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
        }
      });
    },

    removeElementsAfterMoveTo: function (updated_items) {
      var ids = updated_items.split(','), i;
      for(i = 0; i < ids.length; i++) {
        $('.solution-list li[item_id="' + ids[i] + '"]').remove();
      }
      $(".item_ids_checkbox:checked").attr('checked', false);
      $('.comm-item').removeClass('active');
    },
    
    hideSelectAll: function () {
      if ($('#fa_item-select-all:checked').size() > 0) {
        $("#fa_item-select-all").attr('checked', false);
      }
    },

    setCompanyVisibility: function (e) {
      var visibility = e.target.value;
      var form = $(e.target).parents('form');
      if (parseInt(visibility, 10) === 4) {
        form.find('.company_folders').show();
      } else {
        var customers_input = form.find('.autocomplete_filter [type="hidden"]');
        customers_input.val('');
        customers_input.trigger("liszt:updated");
        form.find('.company_folders').hide();
      }
    }
  };
}(window.jQuery));