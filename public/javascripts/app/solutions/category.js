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
      this.setupSearch();
    },
    
    configureSideBar: function () {
      $('#solution-home-sidebar').trigger('afterShow');
      $("body").on('click.solutionCategory', '.drafts-filter-me, .drafts-filter-all', function(e){
        $('.drafts-filter-title').text(e.target.text);
      });
      $("body").on('click.solutionCategory', '.feedbacks-filter-me, .feedbacks-filter-all', function(e){
        $('.feedbacks-filter-title').text(e.target.text);
      });
    },

    bindHandlers: function () {
      $("body").on('click.solutionCategory', '.show-more-cat', function(){
        $('.other-portal-cat').show();
        $('.view-more-cat').hide();
      });
    },

    setupSearch: function () {
      // search bar configuration should be here
    },

    onLeave: function () {
      $('body').off('.solutionCategory');
    }
  };
}(window.jQuery));
