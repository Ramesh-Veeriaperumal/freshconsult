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

      $("body").on('click.solutionCategory', '.feedbacks-filter-all', function (e) {
        $this.changeAllFilterSettings(e,'.feedbacks-filter');
      });

      $("body").on('click.solutionCategory', '.drafts-filter-all', function (e) {
        $this.changeAllFilterSettings(e,'.drafts-filter');
      });

      $("body").on('click.solutionCategory', '.feedbacks-filter-me', function (e) {
        $this.changeMyFilterSettings(e,'.feedbacks-filter');
      });

      $("body").on('click.solutionCategory', '.drafts-filter-me', function (e) {
        $this.changeMyFilterSettings(e,'.drafts-filter');  
      });
    },

    changeAllFilterSettings: function (e,container) {
      $(container+'-title').text($(e.target).text());
      $(container+'-all').parent().addClass('active');
      $(container+'-me').parent().removeClass('active');
    },

    changeMyFilterSettings: function (e,container) {
      $(container+'title').text($(e.target).text());
      $(container+'-me').parent().addClass('active');
      $(container+'-all').parent().removeClass('active');
    },

    bindHandlers: function () {
      var $this = this;
      $("body").on('click.solutionCategory', '.show-more-cat', function (ev) {
        ev.preventDefault();
        $('.other-portal-cat').show();
        $('.view-more-cat').hide();
        $this.normalizeHeight(true);
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
