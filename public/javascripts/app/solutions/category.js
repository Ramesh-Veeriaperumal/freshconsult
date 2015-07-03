/*jslint browser: true, devel: true */
/*global  App, $H, delay */

window.App = window.App || {};
window.App.Solutions = window.App.Solutions || {};
(function ($) {
  "use strict";

  App.Solutions.Category = {
    onVisit: function () {
      this.configureSideBar();
      this.bindHandlers();
      App.Solutions.SearchConfig.onVisit();
    },
    
    configureSideBar: function () {
      $('#solution-home-sidebar').trigger('afterShow');
      $("body").on('click.solutionCategory', '.drafts-filter-me, .drafts-filter-all', function (e) {
        $('.drafts-filter-title').text(e.target.text);
      });
      $("body").on('click.solutionCategory', '.feedbacks-filter-me, .feedbacks-filter-all', function (e) {
        $('.feedbacks-filter-title').text(e.target.text);
      });
    },

    bindHandlers: function () {
      $("body").on('click.solutionCategory', '.show-more-cat', function () {
        $('.other-portal-cat').show();
        $('.view-more-cat').hide();
        return false;
      });
      $("body").on('click.solutionCategory', '#categories_reorder_button', function () {
        $('#search-show').hide();
      });
      $("body").on('click.solutionCategory', '#categories_sort_cancel', function () {
        $('#search-show').show();
      });

      $("body").on('click.solutionCategory', '.orphan-view-all', function () {
        $('.more-orphan-cat').show();
        $('.orphan-view-all').hide();
        $('.orphan-view-less').show();
      });

      $("body").on('click.solutionCategory', '.orphan-view-less', function () {
        $('.more-orphan-cat').hide();
        $('.orphan-view-all').show();
        $('.orphan-view-less').hide();
      });
    },

    onLeave: function () {
      $('body').off('.solutionCategory');
      App.Solutions.SearchConfig.onLeave();
    }
  };
}(window.jQuery));
