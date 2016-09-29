/*jslint browser: true, devel: true */
/*global  App */

window.App = window.App || {};
window.App.Customers = window.App.Customers || {};
window.App.Customers.Tickets = window.App.Customers.Tickets || {};

(function ($) {
  "use strict";

  window.App.Customers.Tickets = {

    init: function () {
      this.initTooltips();
    },

    initTooltips: function(){
      jQuery('.timeline-head a').qtip({
        position: { 
          my: 'top left',
          at: 'bottom  left',
          viewport: jQuery(window)
        },
        style : {
          classes: 'ui-tooltip-ticket ui-tooltip-rounded ui-tooltip-ticket-customers',
          tip: {
            mimic: 'center'
          }
        }
      })
    },

    destroy: function () {
      // Nothing to do right now
    }
  };
}(window.jQuery));