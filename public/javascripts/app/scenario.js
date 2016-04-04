/*jslint browser: true, devel: true */
/*global  App */

window.App = window.App || {};
window.App.Tickets.Scenario = window.App.Tickets.Scenario || {};

(function ($) {
  "use strict";

  window.App.Tickets.Scenario = {

    init: function () {
      this.destroy();
      this.bindSearchEvents();
      this.bindHandlers();
      this.hideSearchBox();
      this.toggleSearchBox();
    },

    bindHandlers: function(){
      $(document).on('shown.scenario', '#execute_scenario', function() {
        $('.dialog-well').focus();
      });

      jQuery(document).on('ajax:send.scenario', '.execute_scenario_form', function(xhr, status, success) {
        jQuery('#execute_scenario .dialog-well').hide();
        jQuery('#execute_scenario .modal-body .sloading').remove();
        jQuery('#execute_scenario .modal-body').append('<div class=\"sloading loading-block\" />');
      });

      jQuery(document).on('click.scenario', '.bulk_scenario_btn', function() {
        var selected_scenario = jQuery(this).data('scenarioId')
        helpdesk_submit("/helpdesk/tickets/execute_bulk_scenario","put",[{name: 'scenario_id' ,  value: selected_scenario}]);
        jQuery('#execute_scenario .dialog-well').hide();
        jQuery('#execute_scenario .modal-body .sloading').remove();
        jQuery('#execute_scenario .modal-body').append('<div class=\"sloading loading-block\" />');
      });
  
    },

    hideSearchBox: function(){
      jQuery('.scenario-search').hide();
    },

    toggleSearchBox: function() {
      if(jQuery(".selected_to_yellow .sa-item").length > 10){
        jQuery('.scenario-search').show();
        jQuery('#search_scenarios').focus();
      }
    },

    bindSearchEvents: function() {
      if(jQuery(".selected_to_yellow .sa-item").length > 10){
        var search_elements = jQuery(".scenarios_table .sa-item");
        var search_elements_text = [];
        search_elements.each(function(){
          search_elements_text.push(jQuery(this).text().toLowerCase());
        });
        jQuery("#search_scenarios").on("keyup.scenario",function(){
          var input_value = jQuery(this).val();
          search_elements.each(function(index){
            jQuery(this).toggle(window.lookups.scenario_execution_search(input_value,search_elements_text[index]))
          });
        });
      }
    },

    destroy: function () {
      jQuery(document).off('.scenario');
    }
  };
}(window.jQuery));