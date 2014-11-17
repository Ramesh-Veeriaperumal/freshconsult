/*jslint browser: true, devel: true */
/*global  App */

window.App = window.App || {};
(function ($) {
  "use strict";

  App.Merge = {
    current_module: '',

    onFirstVisit: function (data) {
      this.onVisit(data);
    },
    onVisit: function (data) {
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
        mark_primary(findOldestTicket());
      }
      entity.children('#resp-icon').addClass('clicked');
    },

    makePrimary: function () {
      jQuery('.merge-cont').removeClass('cont-primary');
      entity.addClass('cont-primary');
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
        jQuery('#merge_freshdialog').modal('hide');
        jQuery('#merge_freshdialog-content').html('<span class="loading-block sloading loading-small">');
      });
    },
    
    onLeave: function (data) {

    }
    
  };
}(window.jQuery));
