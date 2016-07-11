/*jslint browser: true, devel: true */
/*global  App */

window.App = window.App || {};
(function ($) {
  "use strict";

  App.Merge = {
    initialize: function (data) {
      this.bindHandlers();
    },

    bindHandlers: function () {
      this.searchMergeKeyup();
      this.cancelClick();
    },

    clearSearchField: function (entity) {
      jQuery('.search_merge').val("");
      entity.removeClass('typed');
    },

    appendToMergeList: function (element, entity) {
      element.removeClass('cont-primary present-contact');
      element.find('.merge_element').replaceWith(entity.children('.merge_element').clone());
      element.appendTo(jQuery('.merge_entity'));
      // Commented condition was breaking ticket merge
      // console.log(entity);
      if(!jQuery(entity).hasClass('contactdiv')){
        this.makePrimary(App.Tickets.Merge_tickets.findOldestTicket());
      }
      entity.children('#resp-icon').addClass('clicked');
    },

    makePrimary: function (entity) {
      jQuery('.merge-cont').removeClass('cont-primary');
      jQuery('.merge-cont').children('.primary-marker').attr('title','Mark as primary');
      entity.addClass('cont-primary');
      entity.children('.primary-marker').attr('title', 'Primary ticket');
      jQuery('#merge-warning').toggleClass('hide', this.ticketId(entity) === this.ticketId(App.Tickets.Merge_tickets.findOldestTicket()));
    },

    ticketId: function (el) {
      return el.find('#merge-ticket').data('id');
    },

    createdDate: function () {
      return element.find('.merge_element').data('created');
    },

    searchMergeKeyup: function () {
      jQuery('body').on('keyup.merge_helpdesk', '.search_merge', function(){
        jQuery(this).closest('.searchicon').toggleClass('typed', jQuery(this).val()!="");
      });
    },

    cancelClick: function () {
      jQuery('body').on('click.merge_helpdesk', '#cancel_new_merge, #cancel-user-merge', function(){
        if (active_dialog){
          active_dialog.dialog('close');
        }
        jQuery('#mergebox1').modal('hide');
        jQuery('#merge_freshdialog').modal('hide');
        jQuery('#merge_freshdialog-content').html('<span class="loading-block sloading loading-small">');
      });
    }
    
  };
}(window.jQuery));
