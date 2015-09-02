HelpdeskReports.ChartsInitializer = HelpdeskReports.ChartsInitializer || {};

HelpdeskReports.ChartsInitializer.PerformanceDistribution = (function () {
    var _FD = {
        COLORS: {
            'first_response_time' : '#e05651',
            'response_time'       : '#5194CC',
            'resolution_time'     : '#A1C960',
        },
        METRICS_MAPPING: {
            'response'   : ["AVG_RESPONSE_TIME","AVG_FIRST_RESPONSE_TIME"],
            'resolution' : ["AVG_RESOLUTION_TIME"]
        },
        constraints: {
            31: {
                default_trend: 'doy',
                deactive: []
            },
            217: {
                default_trend: 'w',
                deactive: ["doy"]
            },
            930: {
                default_trend: 'mon',
                deactive: ["doy", "w"]
            },
            10000000: {
                default_trend: 'y',
                deactive: ["doy", "w", "mon", "qtr"]
            }
        },
        setMetricDeactive: function(){
            jQuery('#first_response').addClass('active');
            jQuery('#response_time_bar_chart').hide();
        },
        barTrend: function (hash,chart_name) {
            
            var data_array = [];
            var chart_data = hash[chart_name];
            if (!jQuery.isEmptyObject(chart_data)) {
                var current_data   = _.values(chart_data);
                data_array.push({
                    animation: false,
                    dataLabels: { enabled: false },
                    data: this.fillArray(this.arrayElementsSum(current_data),current_data.length),
                    color:  REPORT_COLORS["barChartDummy"],
                    states: { hover: { brightness: 0 } },
                    borderRadius: 5

                },{
                    data: current_data,
                    color: this.COLORS[chart_name],
                    borderRadius: 5
                });
                var labels = _.keys(hash[chart_name]);
                var settings = {
                    renderTo: chart_name+'_bar_chart', 
                    height: this.calculateChartheight(labels.length),
                    xAxisLabel: labels,
                    chartData: data_array,
                    dataLabels: current_data,
                    sharedTooltip: true,
                    timeFormat: false,
                }
                var groupByCharts = new barChart(settings);
                groupByCharts.barChartGraph();
            }else {
                var msg = 'No data to display';
                var div = [chart_name+'_bar_chart'];
                HelpdeskReports.CoreUtil.populateEmptyChart(div, msg);
            }
        },
        responseTimeTrend: function (hash) {
            var time_trend_data = [];
            var dateRange = this.dateRangeLimit();
            var current_trend = dateRange.default_trend;
            if (dateRange.deactive.length) {
                jQuery.each(dateRange.deactive, function (i) {
                    jQuery('[data-format="' + dateRange.deactive[i] + '"][data-chart="response"]').addClass('deactive').attr('title', 'Disabled for this date range');
                });
            }

            HelpdeskReports.locals.trend = current_trend; 
            var chart_data = hash["AVG_RESPONSE_TIME"];
            
            if (!jQuery.isEmptyObject(hash["error"]) || !jQuery.isEmptyObject(chart_data["error"])) {
                var msg = 'Something went wrong, please try again';
                var div = ['response_time_trend_chart'];
                HelpdeskReports.CoreUtil.populateEmptyChart(div, msg);
                jQuery('.response_time_trend.trend-type').hide();
            }else if (jQuery.isEmptyObject(chart_data)) {
                var msg = 'No data to display';
                var div = ['response_time_trend_chart'];
                HelpdeskReports.CoreUtil.populateEmptyChart(div, msg);
                jQuery('.response_time_trend.trend-type').hide();
            }
            else {
                var common_key   = _.keys(chart_data[current_trend]);
            
                time_trend_data.push({
                    name: 'First Response Time',
                    fillOpacity: 0.1,
                    type: 'area',
                    color: this.COLORS['first_response_time'],
                    data: _.values(hash["AVG_FIRST_RESPONSE_TIME"][current_trend]),
                    marker: {
                        fillColor: '#FFFFFF',
                        lineWidth: 1,
                        lineColor: null,
                        radius: 2,
                        symbol: 'circle'
                    }
                },{
                    name: 'Avg Response Time',
                    fillOpacity: 0.1,
                    type: 'area',
                    color: this.COLORS['response_time'],
                    data: _.values(hash["AVG_RESPONSE_TIME"][current_trend]),
                    marker: {
                        fillColor: '#FFFFFF',
                        lineWidth: 1,
                        lineColor: null,
                        radius: 2,
                        symbol: 'circle'
                    }
                });

                _FD.renderCommonChart(time_trend_data, common_key, current_trend, "response");
            }
        },
        resolutionTimeTrend: function (hash) {
            var time_trend_data = [];
            var dateRange = this.dateRangeLimit();
            var current_trend = dateRange.default_trend;
            if (dateRange.deactive.length) {
                jQuery.each(dateRange.deactive, function (i) {
                    jQuery('[data-format="' + dateRange.deactive[i] + '"][data-chart="resolution"]').addClass('deactive').attr('title', 'Disabled for this date range');
                });
            }
            HelpdeskReports.locals.trend = current_trend;
            var chart_data = hash["AVG_RESOLUTION_TIME"];
            
            if (!jQuery.isEmptyObject(hash["error"]) || !jQuery.isEmptyObject(chart_data["error"])) {
                var msg = 'Something went wrong, please try again';
                var div = ['resolution_time_trend_chart'];
                HelpdeskReports.CoreUtil.populateEmptyChart(div, msg);
                jQuery('.resolution_time_trend.trend-type').hide();
            }else if (jQuery.isEmptyObject(chart_data)) {
                var msg = 'No data to display';
                var div = ['resolution_time_trend_chart'];
                HelpdeskReports.CoreUtil.populateEmptyChart(div, msg);
                jQuery('.resolution_time_trend.trend-type').hide();
            }
            else {
                var current_data = _.values(chart_data[current_trend]);
                var current_key  = _.keys(chart_data[current_trend]);
            
                time_trend_data.push({
                    name: 'Avg Resolution Time',
                    fillOpacity: 0.1,
                    type: 'area',
                    color: this.COLORS['resolution_time'],
                    data: current_data,
                    marker: {
                        fillColor: '#FFFFFF',
                        lineWidth: 1,
                        lineColor: null,
                        radius: 2,
                        symbol: 'circle'
                    }
                });
                
                _FD.renderCommonChart(time_trend_data,current_key,current_trend,"resolution");
            }
        },
        renderCommonChart: function(hash, key, trend, charttype){
            var settings = {
                    renderTo: charttype+'_time_trend_chart',
                    xAxisLabel: key,
                    chartData: hash,
                    yAxis_label: "Mins",
                    xAxisType: "trend",
                    report_type: "perf"
                }
                var timeBased = new lineChart(settings);
                timeBased.lineChartGraph();
                
                jQuery('span[data-format="' + trend + '"][data-chart="'+charttype+'"]').addClass('active');
        },
        dateRangeLimit: function () {
            var date_range = HelpdeskReports.locals.date_range.split('-');
            var diff = (Date.parse(date_range[1]) - Date.parse(date_range[0])) / (36e5 * 24);
        
            switch (true) {

                case (diff < 31):
                    return this.constraints['31'];

                case (diff < 217):
                    return this.constraints['217'];

                case (diff < 930):
                    return this.constraints['930'];

                case (diff < 10000000):
                    return this.constraints['10000000'];

            }
        },
        bindChartEvents: function () {
            jQuery('#reports_wrapper').on('click.helpdesk_reports.perf', '[data-chart="resolution"]:not(".deactive"), [data-chart="response"]:not(".deactive")', function () {
                HelpdeskReports.locals.trend = jQuery(this).data('format');
                var charttype = jQuery(this).data('chart');
                jQuery('[data-chart="'+charttype+'"]').removeClass('active');
                jQuery('span[data-format="' + HelpdeskReports.locals.trend + '"][data-chart="'+charttype+'"]').addClass('active');
                _FD.redrawTimeBased(HelpdeskReports.locals.trend, charttype);
            });

            jQuery('#reports_wrapper').on('click.helpdesk_reports.perf', '#response, #first_response', function (event) {
                jQuery('#response, #first_response').toggleClass('active');
                jQuery('#first_response_time_bar_chart, #response_time_bar_chart').toggle();
            });
        },
        redrawTimeBased: function (trend,charttype) {
            var chart  = jQuery('#'+charttype+'_time_trend_chart').highcharts();
            var series = this.METRICS_MAPPING[charttype];
            var labels = _.keys(HelpdeskReports.locals.chart_hash[series[0]][trend]);
            chart.xAxis[0].update({
                categories: labels
            }, false);
            for (i = 0; i < series.length; i++) {
                chart.series[i].update({
                    data: _.values(HelpdeskReports.locals.chart_hash[series[i]][trend])
                }, false);
            }
            chart.redraw(true);
        },
        contructCharts: function (hash) {
            _FD.constants   = HelpdeskReports.Constants.PerformanceDistribution;
            var metrics     = _FD.constants.metrics
            var bucket_name = _FD.constants.bucket_conditions

            jQuery.each(metrics, function (index, value) {
                _FD.barTrend(hash[value+'_BUCKET'],bucket_name[index])
            });
            
            _FD.responseTimeTrend(hash);
            _FD.resolutionTimeTrend(hash);
            _FD.setMetricDeactive();
            _FD.bindChartEvents();
        },
        fillArray: function(value, length) {
            var arr = [];
            for (var i = 0; i < length; i++) {
                arr.push(value);
            }
            return arr;
        },
        calculateChartheight: function (dataPoints) {
            var height = 35 * dataPoints;
            return height;
        },
        arrayElementsSum: function (data) {
            var sum = 0;
            for (var i = 0; i < data.length; i++) {
                sum = sum + data[i];
            };

            return sum;
        }
    };
   return {
        init: function (hash) {
            _FD.contructCharts(hash);
        }
    };
})();

