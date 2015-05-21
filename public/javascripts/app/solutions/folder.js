/*jslint browser: true, devel: true */
/*global  App, moment, highlight_code, Fjax */

window.App = window.App || {};
(function ($) {
  "use strict";

  App.Solutions.Folder = {
    
    data: {},

    onVisit: function (data) {
      console.log("Loaded the folder.js");
    },
    
    onLeave: function (data) {
      $('body').off('.folders');
    },

    bindHandlers: function () {
      var $this = this;
      this.bindForMasterVersion();
      $('body').on('click.articles', '.article-edit-btn', function () {
        $this.startEditing();
      });
    },
		
		toggleViews: function () {
			$('.article-edit, .article-view').toggleClass('hide');
		}

  };
}(window.jQuery));