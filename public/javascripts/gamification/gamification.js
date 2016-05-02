/*jslint browser: true, devel: true */
/*global  App */

window.App = window.App || {};
window.App.Gamification = window.App.Gamification || {};

(function ($) {

  App.Gamification.Leaderboard = {
    startDate: moment().startOf('month'),
    endDate: moment(),
    formatString: "MMM D, YYYY",

    init: function () {
      // Variable Assignments
      this.date_range_val = $('#lb-data-block').data('date_range_val');
      this.selected_range = $('#lb-data-block').data('selected_range');
      
      this.loadDateRangePicker();

      // Click handlers
      this.bindEvent();
    },

    bindEvent: function () {
      $(document).on('click.leaderboard','#lb_select_date_range', this.dateRangeClickHandler.bind(this));
      $(document).on('click.leaderboard','#lb_date_range_select_btn', this.dateRangeSelectedHandler.bind(this));
      $(document).on('click.leaderboard','#lb_date_range_cancel_btn', this.unloadDateRangePicker.bind(this));
    },

    loadDateRangePicker: function(){
      // Change start and end dates if they're sent from the controller
      if(this.date_range_val=="select_range" && this.selected_range.length){
        this.startDate = moment(this.selected_range.split(' - ')[0]);
        this.endDate = moment(this.selected_range.split(' - ')[1]);
      }

      // Store a reference to the input box where picker will be shown
      this.range = $('#lb_date_range_input');
    },
    
    unloadDateRangePicker:function(){
      $("#lb_date_range_dropdown").show();
      $('#lb_custom_date_range').hide();

      if(this.picker){
        this.picker.remove();
        this.picker = null;
      }
    },
    
    dateRangeClickHandler : function(){
      if(!this.picker){
        this.range.bootstrapDaterangepicker({
          "startDate": this.startDate,
          "endDate": this.endDate,
          "opens":"left",
          "maxDate": new Date(),
          "format": this.formatString
        });
        this.picker = this.range.data('bootstrapdaterangepicker');
        this.picker.container.find('.ranges').hide();
      }

      $("#lb_date_range_dropdown").hide();
      $('#lb_custom_date_range').show();

      // Open the daterangepicker on the span.
      this.picker.show();
      this.range.val(this.startDate.format(this.formatString)+" - "+this.endDate.format(this.formatString));
    },
    
    dateRangeSelectedHandler:  function(){
      window.location.search = "?date_range=select_range&date_range_selected="+this.range.val();
    }
  }

  $(document).ready(function(){
    App.Gamification.Leaderboard.init();
  });

}(window.jQuery));
