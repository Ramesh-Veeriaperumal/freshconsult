/*jslint browser: true, devel: true */
/*global  App, $H, delay */

window.App = window.App || {};
window.App.Solutions = window.App.Solutions || {};
(function ($) {
  "use strict";
  App.Solutions.AfterSave = {
    
    currentCategory: null,
    currentPortal: null,

    NAMESPACES: {
      all_categories: 'solution/categories/all_categories',
      category_show: 'solution/categories/show'
    },

    onVisit: function () {
      this.bindHandlers();
    },

    setCurrentObject: function (obj) {
      switch (App.namespace) {
      case this.NAMESPACES.category_show:
        this.currentCategory = obj;
        break;
      case this.NAMESPACES.all_categories:
        this.currentPortal = obj;
        break;
      }
    },

    hide: function (modal) {
      jQuery(modal).modal('hide');
    },

    postCategoryAction: function (portals, partial, element, action) {
      if(App.namespace === this.NAMESPACES.all_categories) {
        if(portals.indexOf(this.currentPortal) !== -1) {
          if(action === 'create') {
            $('#categories_list').append(partial);
          }
          else {
            $('#item_' + element).replaceWith(partial);
          }
        } else {
          $('#item_' + element).remove();
        }
      } else {
        pjaxify('/solution/categories/' + element);
      }
    },

    postFolderAction: function (category, partial, element, action, bulk_actions_partial) {
      if(App.namespace === this.NAMESPACES.category_show) {
        if(this.currentCategory === category) {
          if(action === 'create') {
            $('#folders_list').append(partial);
            if($('#folders_list .comm-item').length === 1) {
              $('.bulk-actions-bar').replaceWith(bulk_actions_partial);
              $('.no-data').remove();
            }
          }
          else {
            $('#item_' + element).replaceWith(partial);
          }
        } else {
          $('#item_' + element).remove();
        }
      } else {
        pjaxify('/solution/folders/' + element);
      }
    },

    bindHandlers: function () {
      
    },

    onLeave: function () {
      $('body').off('.after-save');
    }
  };
}(window.jQuery));