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
    },
    
    configureSideBar: function () {
      var $this = this;
      $('#solution-home-sidebar').trigger('afterShow');
      $('#solution-home-sidebar').one('remoteLoaded', function () {
        $this.normalizeHeight(false);
      })

      $("body").on('click.solutionCategory', '.drafts-filter-me, .drafts-filter-all', function (e) {
        $('.drafts-filter-title').text($(e.target).text());
      });
      $("body").on('click.solutionCategory', '.feedbacks-filter-me, .feedbacks-filter-all', function (e) {
        $('.feedbacks-filter-title').text($(e.target).text());
      });
    },

    bindHandlers: function () {
      var $this = this;
      $("body").on('click.solutionCategory', '.show-more-cat', function (ev) {
        ev.preventDefault();
        $('.other-portal-cat').show();
        $('.view-more-cat').hide();
        $this.normalizeHeight(true);
      });
      $("body").on('click.solutionCategory', '#categories_reorder_button, #categories_sort_cancel', function () {
        $('#search-show').toggle();
      });
      $("body").on('click.solutionCategory', '.orphan-view-all, .orphan-view-less', function () {
        $('.more-orphan-cat').toggle();
        $('.orphan-view-all').toggle();
        $('.orphan-view-less').toggle();
        $this.normalizeHeight(false);
      });
      focusFirstModalElement('solutionCategory');
    },

    normalizeHeight: function (resetCatListHeight) {
      if (resetCatListHeight) {
        $('#categories_list').css('height','');
      }
      var categoryListHeight = $('#categories_list').height(), sideBarHeight = $('.sidepanel').height();
      if (sideBarHeight > categoryListHeight) {
        $('#categories_list').height(sideBarHeight);
      }
    },

    onLeave: function () {
      $('body').off('.solutionCategory');
    }
  };
}(window.jQuery));
