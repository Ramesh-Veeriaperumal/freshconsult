var FreshfoneTrialNumbers;
(function($){
  "use strict";
  FreshfoneTrialNumbers = function () {
    this.chart_options = {
      'chart': {
        'margin': [0, 0, 0, 0],
        'spacing': [0,0,0,0,],
        'borderWidth' : 0,
        'height': 30,
        'backgroundColor': null,
        'borderColor':null,
        'renderTo': null
      },
      'plotOptions':{
        'pie': {
          'animation': false,
          'dataLabels': { 'enabled': false },
          'allowPointSelect': false,
          'shadow': false,
          'borderWidth': 0,
        },
        'series': {
          'shadow':false,
          'states': {
            'hover': {
              'enabled': false
            }
          }
        }
      },
      'credits': { 'enabled': false },
      'title': { 'text': null },
      'tooltip': { 'enabled': false },
      'series': [{
        'type': 'pie',
        'shadow': false,
        'borderWidth': 0,
        'data':[
        {'color': '#95001E', 'y': null},
        {'color': 'rgba(192,192,192,0.2)', 'y': null}]    
      }]
    }; // constant
    this.init();
  };

  FreshfoneTrialNumbers.prototype = {
    init: function(){
      this.incoming_options = $.extend(true, {}, this.chart_options);
      this.outgoing_options = $.extend(true, {}, this.chart_options);
      this.$incoming_chart_container = $('#incoming_usage_container');
      this.$outgoing_chart_container = $('#outgoing_usage_container'); 
      this.incoming_options.chart.renderTo = 'incoming_usage_container';
      this.outgoing_options.chart.renderTo = 'outgoing_usage_container';
      this.incoming_used_minutes = this.$incoming_chart_container.data('usedMinutes');
      this.incoming_usage_limit = this.$incoming_chart_container.data('usageLimit');
      this.outgoing_used_minutes = this.$outgoing_chart_container.data('usedMinutes');
      this.outgoing_usage_limit = this.$outgoing_chart_container.data('usageLimit');
      this.trial_expired = this.$incoming_chart_container.data('trialExpired');
      this.incoming_chart = null;
      this.outgoing_chart = null;
      this.loadHighCharts();

    },
    loadHighCharts: function(){
      var self = this;
      $.get('/assets/highcharts.src.js')
      .then($.get('/assets/highcharts-more.js'))
      .done(function() {self.performCalculations(); }) ;
    },
    performCalculations: function(){
      var self = this;
      self.calculateIncomingMinutes();
      self.calculateOutgoingMinutes();
      self.colorforTrialExpiry();
      self.bindChartRender();
    },
    calculateIncomingMinutes: function(){
      var self = this;
      self.incoming_options.series[0].data[0].y = parseInt(
        (self.incoming_used_minutes/self.incoming_usage_limit) * 100, 10);
      self.incoming_options.series[0].data[1].y = 100 -
        self.incoming_options.series[0].data[0].y; // subtracting as pie takes values on percentage.
    },
    calculateOutgoingMinutes: function(){
      var self = this;
      self.outgoing_options.series[0].data[0].y = parseInt(
          (self.outgoing_used_minutes/self.outgoing_usage_limit)*100, 10);
      self.outgoing_options.series[0].data[1].y = 100 -
        self.outgoing_options.series[0].data[0].y;
    },
    colorforTrialExpiry: function() {
      var self = this;
      if (self.trial_expired){
        self.incoming_options.series[0].data[0].color = '#865A63';
        self.outgoing_options.series[0].data[0].color = '#865A63';
      }
    },
    bindChartRender: function(){  //drawing both charts
      var self = this;
      self.incoming_chart = new Highcharts.Chart(self.incoming_options);
      self.outgoing_chart = new Highcharts.Chart(self.outgoing_options);
    }
  };
  $(document).ready(function(){
    var freshfoneTrialNumbers = new FreshfoneTrialNumbers();
  });
}(jQuery));