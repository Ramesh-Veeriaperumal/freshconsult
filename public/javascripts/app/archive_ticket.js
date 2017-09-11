/*jslint browser: true, devel: true */
/*global  App */

window.App = window.App || {};

(function ($) {
	"use strict";
	App.Archiveticket = {

    current_module: '',

		onFirstVisit: function (data) {
      this.onVisit(data);
    },

    onVisit: function (data) {
      this.setSubModule();
      if (this.current_module == "Archiveticketdetails") {
        App.Archiveticketdetails.init();
      }
    },

    setSubModule: function() {
      switch (App.namespace) {
      case 'helpdesk/archive_tickets/show':
        this.current_module = "Archiveticketdetails";
        break;
      }
    },

    onLeave: function (data) {
      if (this.current_module == "Archiveticketdetails") {
        App.Archiveticketdetails.onLeave();
        this.current_module = '';
      }
    }
	}

}(window.jQuery));