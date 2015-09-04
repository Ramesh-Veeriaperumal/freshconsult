HelpdeskReports.ChartsInitializer = HelpdeskReports.ChartsInitializer || {};

HelpdeskReports.ChartsInitializer.Glance = (function () {
    var _FD = {
        DATA_POINT_LIMIT: 4,
        bucket_series: {
            'agent_interactions': 'Agent Interactions', 
            'customer_interactions' : 'Customer Interactions'
        },
        bindevents: function(){
            jQuery('#reports_wrapper').on('click.helpdesk_reports.glance', "[data-container='view-more'].active", function (event) {
                _FD.actions.viewMoreInit(this);
            });
            jQuery(document).on('click.helpdesk_reports.glance', "[data-action='close-view-all']", function (event) {
                _FD.actions.closeViewMore();
            });
        },
        actions: {
            viewMoreInit: function (el) {
                _FD.renderViewMore(el);
            },
            closeViewMore: function () {
                jQuery('#view_more_wrapper').removeClass('show-all-metrics');
            }
        },
        constructSidebar: function (hash) {
            var tmpl = JST["helpdesk_reports/templates/glance_sidebar"]({
                data: hash
            });
            jQuery('#glance_sidebar').html(tmpl);
            _FD.setMetricActive();
        },
        setMetricActive: function () {
            var metric = HelpdeskReports.locals.active_metric;
            jQuery('#glance_sidebar ul li').removeClass('active');
            jQuery('#glance_sidebar ul li[data-metric="'+metric+'"]').addClass('active');
        },
        contructCharts: function (hash) {
            var active_metric = HelpdeskReports.locals.active_metric;
            var hash_active = hash[active_metric];
            var group_by = HelpdeskReports.locals.current_group_by;
            HelpdeskReports.CoreUtil.flushCharts();
            jQuery('#glance_main').html('');            

            if (jQuery.isEmptyObject(hash_active['error'])) {
                for (i = 0; i < group_by.length; i++) {
                    var group_tmpl = JST["helpdesk_reports/templates/glance_group_by"]({
                        data: group_by[i],
                        metric: active_metric
                    });
                    jQuery('#glance_main').append(group_tmpl);

                    if (!jQuery.isEmptyObject(hash_active[group_by[i]])) {
                        _FD.constructChartSettings(hash_active, group_by[i], false);
                    } else {
                        var msg = 'No data to display';
                        var div = [group_by[i] + '_container'];
                        HelpdeskReports.CoreUtil.populateEmptyChart(div, msg);
                    }
                }

                if(HelpdeskReports.Constants.Glance.bucket_condition_metrics.indexOf(active_metric) > -1) {
                    _FD.renderBucketConditionsGraph(hash,active_metric);
                }
            } else {
                var msg = 'Something went wrong, please try again';
                var div = ["glance_main"];
                HelpdeskReports.CoreUtil.populateEmptyChart(div, msg);
            }

        },
        constructChartSettings: function (hash_active, group_by, view_all) {
            var active_metric = HelpdeskReports.locals.active_metric;
            var constants = jQuery.extend({}, HelpdeskReports.Constants.Glance);
            var options = {};
            var current_hash = hash_active[group_by];

            if (constants.percentage_metrics.indexOf(active_metric) > -1) {

                options = {    
                    color : REPORT_COLORS["barChartPercent"],
                    radius : null,
                    lrRadius : 5,
                    value : 100,
                    sharedTooltip: false,
                    timeFormat: false,
                    suffix: '{value}%'
                }

            } else {

                var value;
                if (view_all) {
                    value = _.max(_.values(current_hash));
                } else {
                    value = _.max(_.first(_.values(current_hash),_FD.DATA_POINT_LIMIT));
                }
                options = {    
                    color : REPORT_COLORS["plotBG"],
                    radius : 5,
                    lrRadius : null,
                    value : value,
                    sharedTooltip: true,
                    timeFormat: (constants.time_metrics.indexOf(active_metric) > -1) ? true : false
                }

            }
            _FD.renderCommonChart(current_hash, options, group_by, view_all);
        },
        renderCommonChart: function (current_hash, options, group_by, view_all) {
            var height, data1, data2, dataLab, labels, container;
            if (view_all) {
                labels = _.keys(current_hash);
                height = _FD.calculateChartheight(labels.length);
                dataLab = _.values(current_hash);
                data1 = this.fillArray(options.value,_.values(current_hash).length);
                data2 = _.values(current_hash);
                container = 'view_all';
            } else {
                if (_.values(current_hash).length > _FD.DATA_POINT_LIMIT) {
                    labels = _.first(_.keys(current_hash), _FD.DATA_POINT_LIMIT);
                    height = _FD.calculateChartheight(_FD.DATA_POINT_LIMIT);
                    dataLab = _.first(_.values(current_hash),_FD.DATA_POINT_LIMIT);
                    data1 = this.fillArray(options.value, _FD.DATA_POINT_LIMIT);
                    data2 = _.first(_.values(current_hash),_FD.DATA_POINT_LIMIT); 

                    jQuery("[data-group-container='"+ group_by +"']").addClass('active');

                } else {
                    labels = _.keys(current_hash);
                    height = _FD.calculateChartheight(labels.length);
                    dataLab = _.values(current_hash);
                    data1 = this.fillArray(options.value,_.values(current_hash).length);
                    data2 = _.values(current_hash);

                    jQuery("[data-group-container='"+ group_by +"']").removeClass('active');
                    
                }
                container = group_by;
            }

            var data_array = [];
            data_array.push({
                animation: false,
                dataLabels: { enabled: false },
                //data: this.fillArray(options.value,_.values(current_hash).length),
                data: data1,
                color: options.color,
                states: { hover: { brightness: 0 } },
                borderRadius: 5
            }, {
                data: data2,
                color: REPORT_COLORS['barChartReal'],
                borderRadius: 5,
                animation: {
                    duration: 1000,
                    easing: 'easeInOutQuart'
                }
                //borderRadius: options.radius,
                // borderRadiusBottomRight: options.lrRadius,
                // borderRadiusBottomLeft: options.lrRadius
                // events: {
                //     click: function (ev) {
                //         console.log('Category: ' + ev.point.category + ', value: ' + ev.point.y);
                //     }
                // }
            });
            var settings = {
                renderTo: container + "_container",
                height: height,
                xAxisLabel: labels,
                chartData: data_array,
                dataLabels: dataLab,
                sharedTooltip: options.sharedTooltip,
                timeFormat: options.timeFormat,
                suffix: options.suffix
            }
            var groupByCharts = new barChart(settings);
            groupByCharts.barChartGraph();
        },
        renderBucketConditionsGraph: function (hash,metric) {
            var key = metric + '_BUCKET'
            if (hash[key] !== undefined) {
                var tmpl = JST["helpdesk_reports/templates/bucket_conditions_div"]({
                    data: 'bucket_conditions'
                });
                jQuery('#glance_main').append(tmpl);

                if (!jQuery.isEmptyObject(hash[key])) {
                    var data_array = [];
                    var series = _.keys(_FD.bucket_series);
                    for (i = 0; i < series.length; i++) {
                        data_array.push({
                            name: _FD.bucket_series[series[i]],
                            data: _.values(hash[key][series[i]]).reverse(),
                            legendIndex: i
                        });
                    }

                    var labels = _.keys(hash[key][series[0]]).reverse();
                    var settings = {
                        renderTo: "bucket_conditions_container",
                        height: '325',
                        xAxisLabel: labels,
                        chartData: data_array,
                        xAxis_title: 'No. of Interactions',
                        yAxis_title: 'No. of Tickets',
                    }

                    var bucketChart = new barChartMultipleSeries(settings);
                    bucketChart.barChartSeriesGraph();
                } else {
                    var msg = 'No data to display';
                    var div = ["bucket_conditions_container"];
                    HelpdeskReports.CoreUtil.populateEmptyChart(div, msg);
                }
                    
            }
        },
        customFields: function (hash) {
            var locals = HelpdeskReports.locals
            var active_custom_field = locals.active_custom_field;
            jQuery('#custom_field_group_by .half-container').attr('id', active_custom_field + '_container');
            jQuery('#custom_field_group_by .half-container').attr('data-group', active_custom_field);
            jQuery("#custom_field_group_by [data-container='view-more']").attr("data-group-container", active_custom_field);
            if (jQuery.isEmptyObject(hash[locals.active_metric]["error"]) && !jQuery.isEmptyObject(hash[locals.active_metric])) {
                _FD.renderCustomFieldChart(hash, active_custom_field);

            } else if (jQuery.isEmptyObject(hash[locals.active_metric])) {
                var msg = 'No data to display';
                var div = [active_custom_field + '_container'];
                HelpdeskReports.CoreUtil.populateEmptyChart(div, msg);
            
            } else if (!jQuery.isEmptyObject(hash[locals.active_metric]["error"])) {
                var msg = 'Something went wrong, please try again';
                var div = [active_custom_field + '_container'];
                HelpdeskReports.CoreUtil.populateEmptyChart(div, msg);
            
            }
        },
        renderCustomFieldChart: function(hash, id) {
            var custom_field_chart  = jQuery('#' + id + '_container').highcharts();
            var active_metric = HelpdeskReports.locals.active_metric;
            var active_hash = hash[active_metric];
            if (custom_field_chart !== undefined) {
                custom_field_chart.destroy();
            }
            _FD.constructChartSettings(active_hash, id, false);
        },
        renderViewMore: function (el) {
            var attr = jQuery(el).data('group-container');
            var active_metric_hash = HelpdeskReports.locals.active_metric_data_hash;
            var active_cf_hash = HelpdeskReports.locals.custom_field_data_hash;
            if (!jQuery.isEmptyObject(active_metric_hash[attr])) {
                _FD.constructChartSettings(active_metric_hash, attr, true);
            } else if(!jQuery.isEmptyObject(active_cf_hash[attr])) {
                _FD.constructChartSettings(active_cf_hash, attr, true);
            } else {
                console.log('Data not available');
            }

            if (!jQuery('#view_more_wrapper').hasClass('show-all-metrics')) {
                jQuery('#view_more_wrapper').addClass('show-all-metrics');
            }

            if (jQuery(el).closest('.chart-container').attr('id') !== 'custom_field_group_by') {
                var title = jQuery(el).siblings('.title').text().trim();
            } else {
                var title_el = jQuery(el).siblings('.title');
                var title = title_el.find('.rep-title-sub').text().trim();
                title = title + ' ' + title_el.children('select').find('option:selected').text().trim();
            }

            jQuery('#view_title').text(title);
        },
        fillArray: function(value, length) {
            var arr = [];
            for (var i = 0; i < length; i++) {
                arr.push(value);
            }
            return arr;
        },
        calculateChartheight: function (dataPoints) {
            var height = 50 * dataPoints;
            return height;
        }
    };
   return {
        init: function (hash) {
            _FD.bindevents();

            if(_.keys(hash).length > 2) {
                _FD.constructSidebar(hash);
            }

            _FD.contructCharts(hash);

            HelpdeskReports.locals.active_metric_data_hash = hash[HelpdeskReports.locals.active_metric];
        },
        customFieldInit: function (hash) {
            _FD.customFields(hash);
            HelpdeskReports.locals.custom_field_data_hash = hash[HelpdeskReports.locals.active_metric];
        }
    };
})();