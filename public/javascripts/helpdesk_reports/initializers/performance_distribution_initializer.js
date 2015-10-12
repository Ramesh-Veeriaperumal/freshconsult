HelpdeskReports.ChartsInitializer = HelpdeskReports.ChartsInitializer || {};

HelpdeskReports.ChartsInitializer.PerformanceDistribution = (function () {
    var _FD = {
        DEFAULT_TREND_WEEK: 'w',
        DEFAULT_TREND_DAYS: 'doy',
        COLORS: {
            'first_response_time' : '#e05651',
            'response_time'       : '#5194CC',
            'resolution_time'     : '#A1C960',
        },
        METRICS_MAPPING: {
            'response'   : ["AVG_FIRST_RESPONSE_TIME","AVG_RESPONSE_TIME"],
            'resolution' : ["AVG_RESOLUTION_TIME"]
        },
        setMetricDeactive: function(){
            jQuery('#first_response').addClass('active');
            jQuery('#response_time_bar_chart').hide();
        },
        TICK_INTERVAL_MAPPING: {
            'doy' : 24 * 3600 * 1000,
            'w'   : 7 * 24 * 3600 * 1000,
            'mon' : 30 * 24 * 3600 * 1000,
            'qtr' : 90 * 24 * 3600 * 1000,
            'y'   : 365 * 24 * 3600 * 1000,
        },
        LABEL_MAPPING: {
            'doy': '{value:%e %b \'%y}',
            'w'  : '{value: %W \'%y}',
            'mon': '{value:%b, %Y}',
            'qtr': '{value:%qtr, %Y}',
            'y'  : '{value:%Y}'
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
                    cursor: 'pointer',
                    point: {
                        events: {
                            click: function () {
                                var ev = this; 
                                _FD.ticketListEvent(ev);
                            }
                        }
                    },
                    borderRadius: 5,
                    animation: {
                        duration: 1000,
                        easing: 'easeInOutQuart'
                    },
                    total: hash["tickets_count"][chart_name]
                });
                var labels = _.keys(hash[chart_name]);
                var settings = {
                    renderTo: chart_name+'_bar_chart', 
                    height: this.calculateChartheight(labels.length),
                    xAxisLabel: labels,
                    chartData: data_array,
                    dataLabels: current_data,
                    sharedTooltip: true,
                    enableTooltip: true,
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
        ticketListEvent: function (ev) {
            var data = {};
            var hash = HelpdeskReports.locals.chart_hash;
            var chart = ev.series.chart.container;
            var label = ev.category;

            data.bucket = jQuery(chart).closest('.chart-wrapper').data('bucket-name');
            data.metric = jQuery(chart).closest('.chart-wrapper').data('metric-name');
            data.value = hash[data.metric+'_BUCKET']['value_map'][data.bucket][label][0];
            data.operator =  hash[data.metric+'_BUCKET']['value_map'][data.bucket][label][1];

            trigger_event("perf_ticket_list.helpdesk_reports", data);
        },
        responseTimeTrend: function (hash) {
            var time_trend_data = [];
            var current_trend = HelpdeskReports.CoreUtil.dateRangeDiff() >= 6 ? this.DEFAULT_TREND_WEEK : this.DEFAULT_TREND_DAYS;
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

                var first_response_data = this.convertingIntoFractionalPart(_.values(hash["AVG_FIRST_RESPONSE_TIME"][current_trend]),plot_type);
                var response_data       = this.convertingIntoFractionalPart(_.values(hash["AVG_RESPONSE_TIME"][current_trend]),plot_type);
                var data_length         = _.size(hash["AVG_RESPONSE_TIME"][current_trend]);
                var plot_type           = (_.max(hash["AVG_FIRST_RESPONSE_TIME"][current_trend]) > 3600 || _.max(hash["AVG_RESPONSE_TIME"][current_trend]) > 3600 ) ? 'Hours' : 'Mins';                
                var start_value         = _.keys(hash["AVG_RESPONSE_TIME"][current_trend])[0];
                var end_value           = _.keys(hash["AVG_RESPONSE_TIME"][current_trend])[data_length-1];
                var markerStatus = data_length > 90 ? false : true;
                var markerValue  = {
                        enabled: markerStatus ? true : false,
                        fillColor: '#FFFFFF',
                        lineWidth: 1,
                        lineColor: null,
                        radius: 2,
                        symbol: 'circle'
                    };

                HelpdeskReports.locals.response = plot_type;
    
                time_trend_data.push({
                    name: 'Avg First Response Time',
                    fillOpacity: 0.1,
                    type: 'area',
                    color: this.COLORS['first_response_time'],
                    data: this.convertHashIntoArrayOfArray(hash["AVG_FIRST_RESPONSE_TIME"][current_trend],plot_type),
                    marker: markerValue,
                    pointInterval: this.TICK_INTERVAL_MAPPING[current_trend]
                },{
                    name: 'Avg Response Time',
                    fillOpacity: 0.1,
                    type: 'area',
                    color: this.COLORS['response_time'],
                    data: this.convertHashIntoArrayOfArray(hash["AVG_RESPONSE_TIME"][current_trend],plot_type),                    
                    marker: markerValue,
                    pointInterval: this.TICK_INTERVAL_MAPPING[current_trend]
                });

                _FD.renderCommonChart(time_trend_data, current_trend, data_length, plot_type, start_value, end_value, "response");
            }
        },
        resolutionTimeTrend: function (hash) {
            var time_trend_data = [];
            var current_trend = HelpdeskReports.CoreUtil.dateRangeDiff() >= 6 ? this.DEFAULT_TREND_WEEK : this.DEFAULT_TREND_DAYS;
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
                var data_length     = _.size(chart_data[current_trend]);
                var markerStatus    = data_length > 90 ? false : true;
                var plot_type       = _.max(chart_data[current_trend]) > 3600 ? 'Hours' : 'Mins';
                var start_value     = _.keys(chart_data[current_trend])[0];
                var end_value       = _.keys(chart_data[current_trend])[data_length-1];
                var markerValue     = {
                        enabled: markerStatus ? true : false,
                        fillColor: '#FFFFFF',
                        lineWidth: 1,
                        lineColor: null,
                        radius: 2,
                        symbol: 'circle'
                    };    

                HelpdeskReports.locals.resolution = plot_type;
                    
                time_trend_data.push({
                    name: 'Avg Resolution Time',
                    fillOpacity: 0.1,
                    type: 'area',
                    color: this.COLORS['resolution_time'],
                    data: this.convertHashIntoArrayOfArray(hash["AVG_RESOLUTION_TIME"][current_trend],plot_type),
                    marker: markerValue,
                    pointInterval: this.TICK_INTERVAL_MAPPING[current_trend],
                });
                
                _FD.renderCommonChart(time_trend_data, current_trend, data_length, plot_type, start_value, end_value,"resolution");
            }
        },
        renderCommonChart: function(hash, trend, length, plot_type, start_value,end_value,charttype){
            var responseTimeStamp   = _.keys(HelpdeskReports.locals.chart_hash['AVG_RESPONSE_TIME']['doy'])[0];
            var resolutionTimeStamp = _.keys(HelpdeskReports.locals.chart_hash['AVG_RESOLUTION_TIME']['doy'])[0];
            HelpdeskReports.locals.startTimestamp = (typeof responseTimeStamp === 'undefined') ? ((typeof resolutionTimeStamp === 'undefined') ? null : resolutionTimeStamp ) : responseTimeStamp

            HelpdeskReports.locals.response       = plot_type;
                
            var stepValue = Math.ceil(length/11);                
                stepValue = stepValue <= 0 ? 1 : stepValue;

            var settings = {
                    renderTo: charttype+'_time_trend_chart',
                    chartData: hash,
                    yAxis_label: plot_type,
                    report_type: "perf",
                    start_date: start_value,
                    end_date: end_value,
                    xAxisFormat: this.LABEL_MAPPING[trend],
                    xAxisTickInterval: this.TICK_INTERVAL_MAPPING[trend],
                    xAxisStepValue: stepValue
                }
                var timeBased = new perfLineChart(settings);
                timeBased.perfLineChartGraph();
                
                jQuery('span[data-format="' + trend + '"][data-chart="'+charttype+'"]').addClass('active');
        },
        bindChartEvents: function () {
            jQuery('#reports_wrapper').on('click.helpdesk_reports.perf', '[data-chart="resolution"]:not(".deactive"), [data-chart="response"]:not(".deactive")', function () {
                HelpdeskReports.locals.trend = jQuery(this).data('format');
                var charttype = jQuery(this).data('chart');
                jQuery('[data-chart="'+charttype+'"]').removeClass('active');
                jQuery('span[data-format="' + HelpdeskReports.locals.trend + '"][data-chart="'+charttype+'"]').addClass('active');
                _FD.redrawTimeBased(HelpdeskReports.locals.trend, charttype);
            });

            jQuery('#reports_wrapper').on('click.helpdesk_reports.perf', '#response:not(".active"), #first_response:not(".active")', function (event) {
                jQuery('#response, #first_response').toggleClass('active');
                jQuery('#first_response_time_bar_chart, #response_time_bar_chart').toggle();
            });
        },
        redrawTimeBased: function (trend,charttype) {
            var chart        = jQuery('#'+charttype+'_time_trend_chart').highcharts();
            var series       = this.METRICS_MAPPING[charttype];
            var plot_type    = HelpdeskReports.locals[charttype];
            var xAxisLength  = _.size(HelpdeskReports.locals.chart_hash[series[0]][trend]);
            var start_value  = _.keys(HelpdeskReports.locals.chart_hash[series[0]][trend])[0];
            var end_value    = _.keys(HelpdeskReports.locals.chart_hash[series[0]][trend])[xAxisLength-1];
            var markerStatus = xAxisLength > 90 ? false : true;
            var stepValue    =  Math.ceil(xAxisLength/11);                
                stepValue    = stepValue <= 0 ? 1 : stepValue;
                
            chart.xAxis[0].update({ 
                    labels: {
                        format: this.LABEL_MAPPING[trend],
                        step: stepValue,
                    },  
                    tickInterval: this.TICK_INTERVAL_MAPPING[trend],  
                    min: start_value,
                    max: end_value,
                }, false);

            for (i = 0; i < series.length; i++) {
                chart.series[i].update({
                    data: this.convertHashIntoArrayOfArray(HelpdeskReports.locals.chart_hash[series[i]][trend],plot_type),
                    marker: {
                        enabled: markerStatus ? true : false //Disabling marker if no. of points is gr8 than 90.
                    },
                    pointInterval: this.TICK_INTERVAL_MAPPING[trend]
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
        },
        convertingIntoFractionalPart: function(data,type) {
            var arr = [];
            var divider = (type === 'Hours') ? 3600 : 60
            for (var i = 0; i < data.length; i++) {
                arr.push(parseFloat((data[i]/divider).toFixed(2)));
            }
            return arr;
        },       
        convertHashIntoArrayOfArray: function(hash,type){
            if(typeof hash === 'undefined')
                return [];
            arrArr = [];
            var divider = (type === 'Hours') ? 3600 : 60
            jQuery.each(hash, function(i,value){
                arrArr.push([parseInt(i),parseFloat((value/divider).toPrecision(12))]);
            });
            return arrArr;
        },
    };
   return {
        init: function (hash) {
            _FD.contructCharts(hash);
        }
    };
})();

