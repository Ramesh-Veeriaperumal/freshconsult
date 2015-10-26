HelpdeskReports.ChartsInitializer = HelpdeskReports.ChartsInitializer || {};

HelpdeskReports.ChartsInitializer.CustomerReport = (function () {
    var _FD = {
        TOGGLE_ORDER: {
            "ASC"  : "DESC",
            "DESC" : "ASC"
        },
        bindevents: function(){
            jQuery('#reports_wrapper').on('click.helpdesk_reports.cust', "[data-container='toggle']", function (event) {
                HelpdeskReports.CoreUtil.actions.hideTicketList();
                HelpdeskReports.CoreUtil.actions.closeFilterMenu();
                metric     = jQuery(this).data('chart');
                sort_order = jQuery(this).data('sorting');
                sort_icon  = jQuery(this).find("i");
                sort_icon.toggleClass("ficon-reports-sorting-desc ficon-reports-sorting-asc");
                jQuery(this).data('sorting',_FD.TOGGLE_ORDER[sort_order]);
                _FD.redraw(metric,sort_order);
            });
        },
        contructCharts: function (hash) {
            var metrics = _.keys(_FD.constants.metrics);
            HelpdeskReports.CoreUtil.flushCharts();
            jQuery('#customer_report_main').html('');            

            for (i = 0; i < metrics.length; i++) {
                var tmpl = JST["helpdesk_reports/templates/customer_report_chart"]({
                    metric: metrics[i]
                });
                jQuery('#customer_report_main').append(tmpl);
                if(!jQuery.isEmptyObject(hash[metrics[i]]['error'])){
                    var msg = 'Something went wrong, please try again';
                    var div = [metrics[i] + '_container'];
                    jQuery("[data-chart='"+ metrics[i] +"']").hide();
                    HelpdeskReports.CoreUtil.populateEmptyChart(div, msg);
                }
                else if (!jQuery.isEmptyObject(hash[metrics[i]]['company_id'])) {
                    _FD.constructChartSettings(hash, metrics[i]);
                } else {
                    var msg = 'No data to display';
                    var div = [metrics[i] + '_container'];
                    jQuery("[data-chart='"+ metrics[i] +"']").hide();
                    HelpdeskReports.CoreUtil.populateEmptyChart(div, msg);
                }
            }    
        },
        constructChartSettings: function (hash_active, metric) {
            var constants    = _FD.constants; 
            var current_hash = hash_active[metric]['company_id']['DESC'];
            var options = {    
                    color : REPORT_COLORS["plotBG"],
                    radius : 5,
                    lrRadius : null,
                    maxValue : (constants.percentage_metrics.indexOf(metric) > -1) ? 100 : _FD.calculateMaxValue(current_hash),
                    enableTooltip: false,
                    cursor: 'default',
                    suffix: (constants.percentage_metrics.indexOf(metric) > -1) ? '{value}%' : null,
                }   
            _FD.renderCommonChart(current_hash, options, metric);
        },
        calculateMaxValue: function (hash) {
            var modified_hash = _.values(hash); 
            var values = []; 
            for (var i = 0; i < modified_hash.length; i++) { 
                values.push(modified_hash[i].value);
            };

            return _.max(values);
        },
        renderCommonChart: function (current_hash, options, metric) {
            var constants = _FD.constants;
            var current_value_array = [];
            
            _.each(_.values(current_hash), function(i) {
                current_value_array.push(i.value);
            });
            
            var values    = current_value_array; //_.values(current_hash);
            var labels    = _.keys(current_hash);
            var color     = constants.percentage_metrics.indexOf(metric) > -1 ? REPORT_COLORS["barChartPercent"] : REPORT_COLORS['barChartReal'];
            var height    = _FD.calculateChartheight(labels.length);
        
            var data_array = [];
            data_array.push({
                data: values,
                color: color,
                borderRadius: 5,
                animation: {
                    duration: 1000,
                    easing: 'easeInOutQuart'
                },
                cursor: 'pointer',
                point: {
                    events: {
                        click: function () {
                            var ev = this;
                            _FD.clickEventForTicketList(ev);
                        }
                    }
                },
            });
            var settings = {
                renderTo: metric + "_container",
                height: height,
                xAxisLabel: labels,
                chartData: data_array,
                dataLabels: values,
                sharedTooltip: options.sharedTooltip,
                enableTooltip: options.enableTooltip,
                minPoint: options.minPoint,
                suffix: options.suffix,
                yAxisMaxValue: options.maxValue
            }
            var barCharts = new barChart(settings);
            barCharts.barChartGraph();
        },
        clickEventForTicketList: function (el) {
                var data = {};
                data.label = el.category;
                var container = el.series.chart.container;
                data.metric = jQuery(container).closest('[data-report="customer-report-container"]').data('metric');
                            
                trigger_event("customer_report_ticket_list.helpdesk_reports", data);
        },
        redraw: function (metric,sort_order) {
            var chart = jQuery('#'+metric+'_container').highcharts();
            var hash  = HelpdeskReports.locals.chart_hash[metric]
            if(!jQuery.isEmptyObject(hash)){
                var current_hash = hash['company_id'][sort_order];
                var current_value_array = [];
                
                _.each(_.values(current_hash), function(i) {
                    current_value_array.push(i.value);
                });
                
                var values = current_value_array;

                chart.xAxis[0].update({
                    categories: _.keys(current_hash)
                },false);

                chart.xAxis[1].update({
                    categories: values
                },false);

                chart.series[0].update({
                    data: values
                }, false);

                chart.redraw(true);
            }    
        },
        calculateChartheight: function (dataPoints) {
            var height = 50 * dataPoints;
            return height;
        }
    };
   return {
        init: function (hash) {
            _FD.constants = HelpdeskReports.Constants.CustomerReport;
            _FD.bindevents();
            _FD.contructCharts(hash);
        }
    };
})();