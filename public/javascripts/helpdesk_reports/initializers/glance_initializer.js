HelpdeskReports.ChartsInitializer = HelpdeskReports.ChartsInitializer || {};

HelpdeskReports.ChartsInitializer.Glance = (function () {
    var _FD = {
        DATA_POINT_LIMIT: 4,
        DATA_POINT_LIMIT_PDF: 11,
        GROUP_BY_LIMITING_KEY: '-Others',
        bindevents: function(){
            jQuery('#reports_wrapper').on('click.helpdesk_reports.glance', "[data-container='view-more'].active", function (event) {
                HelpdeskReports.CoreUtil.actions.hideTicketList();
                HelpdeskReports.CoreUtil.actions.closeFilterMenu();
                _FD.actions.viewMoreInit(this);
            });
            jQuery(document).on('click.helpdesk_reports.glance', "[data-action='close-view-all']", function (event) {
                HelpdeskReports.CoreUtil.actions.hideViewMore();
            });
        },
        actions: {
            viewMoreInit: function (el) {
                _FD.renderViewMore(el);
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
                        _FD.constructChartSettings(hash_active, group_by[i], false, false);
                    } else {
                        var msg = 'No data to display';
                        var div = [group_by[i] + '_container'];
                        HelpdeskReports.CoreUtil.populateEmptyChart(div, msg);
                    }
                }

                if(HelpdeskReports.Constants.Glance.bucket_condition_metrics.indexOf(active_metric) > -1) {
                    var bucket_types = HelpdeskReports.Constants.Glance.metrics[active_metric].bucket_graph_map;
                    for (var i = 0; i < bucket_types.length; i++) {
                        _FD.renderBucketConditionsGraph(hash, active_metric, bucket_types[i]);
                    }
                }

            } else {
                var msg = 'Something went wrong, please try again';
                var div = ["glance_main"];
                HelpdeskReports.CoreUtil.populateEmptyChart(div, msg);
            }

        },
        contructPdfCharts: function (hash) {
            HelpdeskReports.CoreUtil.flushCharts();
            jQuery('#glance_main').html('');
            var metrics =  _.keys(hash);
            var pdf_tmpl = JST["helpdesk_reports/templates/glance_pdf"]({
                                metrics: metrics,
                                result_hash: hash
                            });
            jQuery('#glance_main').append(pdf_tmpl);
            for(m = 0; m < metrics.length; m++){
                if(metrics[m].substring(metrics[m].length - 6) !== 'BUCKET'){
                    var active_metric = metrics[m];
                    var hash_active = hash[active_metric];
                    var group_by = HelpdeskReports.CoreUtil.setDefaultGroupByOptions(active_metric); 
                    if(HelpdeskReports.locals.pdf_custom_field !== 'none'){
                        group_by.push(HelpdeskReports.locals.pdf_custom_field)
                    }         
                    if (jQuery.isEmptyObject(hash_active['error'])) {
                        for (i = 0; i < group_by.length; i++) {
                            var group_tmpl = JST["helpdesk_reports/templates/glance_group_by_pdf"]({
                                data: group_by[i],
                                metric: active_metric
                            });
                            var div_id = '#'+active_metric.toLowerCase();
                            jQuery(div_id).append(group_tmpl);

                            if (!jQuery.isEmptyObject(hash_active[group_by[i]])) {
                                _FD.constructChartSettings(hash_active, group_by[i], false, active_metric);
                            } else {
                                var msg = 'No data to display';
                                var div = [active_metric+'_'+group_by[i] + '_container'];
                                HelpdeskReports.CoreUtil.populateEmptyChart(div, msg);
                            }
                        }

                        if(HelpdeskReports.Constants.Glance.bucket_condition_metrics.indexOf(active_metric) > -1) {
                            var bucket_types = HelpdeskReports.Constants.Glance.metrics[active_metric].bucket_graph_map;
                            for (var i = 0; i < bucket_types.length; i++) {
                                _FD.renderBucketConditionsGraph(hash, active_metric, bucket_types[i]);
                            }
                        }

                    } else {
                        var msg = 'Something went wrong, please try again';
                        var div = [active_metric.toLowerCase()];
                        HelpdeskReports.CoreUtil.populateEmptyChart(div, msg);
                    }
                }
            }

        },
        constructChartSettings: function (hash_active, group_by, view_all, metric) {
            var active_metric = metric || HelpdeskReports.locals.active_metric;
            var constants = jQuery.extend({}, HelpdeskReports.Constants.Glance);
            var options = {};
            var current_hash = _FD.getCurrentHash(hash_active[group_by]) //hash_active[group_by];

            var current_value_array = [];
            _.each(_.values(current_hash), function(i) {
                current_value_array.push(i.value);
            });

            if (constants.percentage_metrics.indexOf(active_metric) > -1) {

                options = {    
                    color : REPORT_COLORS["barChartPercent"],
                    radius : null,
                    lrRadius : 5,
                    value : 100,
                    sharedTooltip: false,
                    enableTooltip: true,
                    timeFormat: false,
                    suffix: '{value}%',
                    cursor: 'pointer',
                    first_series: 'violated',
                    second_series: 'compliant'
                }

            } else {
                var value;
                if (view_all) {
                    value = _.max(current_value_array);
                } else {
                    value = _.max(_.first(current_value_array,_FD.dataPointLimit()));
                }
                options = {    
                    color : REPORT_COLORS["plotBG"],
                    radius : 5,
                    lrRadius : null,
                    value : value,
                    sharedTooltip: true,
                    enableTooltip: (constants.time_metrics.indexOf(active_metric) > -1) ? false : true,
                    timeFormat: (constants.time_metrics.indexOf(active_metric) > -1) ? true : false,
                    minPoint: true,
                    cursor: 'default',
                    first_series: 'dummy',
                    second_series: 'actual',
                    total: hash_active['general']['metric_result']
                }

            }
            _FD.renderCommonChart(current_hash, options, group_by, view_all, current_value_array, metric);
        },
        renderCommonChart: function (current_hash, options, group_by, view_all, current_value_array, metric) {
            var height, data1, data2, dataLab, labels, container;
            if (view_all) {
                labels = _.keys(current_hash);
                height = _FD.calculateChartheight(labels.length);
                dataLab = current_value_array;
                data1 = this.fillArray(options.value,current_value_array.length);
                data2 = current_value_array;
                container = 'view_all';
            } else {
                var point_limit = _FD.dataPointLimit();
                if (current_value_array.length > point_limit) {
                    labels = _.first(_.keys(current_hash), point_limit);
                    height = _FD.calculateChartheight(point_limit);
                    dataLab = _.first(current_value_array,point_limit);
                    data1 = this.fillArray(options.value, point_limit);
                    data2 = _.first(current_value_array,point_limit); 

                    jQuery("[data-group-container='"+ group_by +"']").addClass('active');

                } else {
                    labels = _.keys(current_hash);
                    height = _FD.calculateChartheight(labels.length);
                    dataLab = current_value_array;
                    data1 = this.fillArray(options.value,current_value_array.length);
                    data2 = current_value_array;

                    jQuery("[data-group-container='"+ group_by +"']").removeClass('active');
                    
                }
                if (HelpdeskReports.locals.pdf !== undefined){
                    container = metric+'_'+group_by;
                } else {
                    container = group_by; 
                }
                
            }

            var data_array = [];
            data_array.push({
                animation: false,
                dataLabels: { enabled: false },
                data: data1,
                color: options.color,
                states: { hover: { brightness: 0 } },
                borderRadius: 5,
                cursor: HelpdeskReports.locals.enable_ticket_list ? 'pointer' : null,
                name: options.first_series,
                clickable: HelpdeskReports.locals.enable_ticket_list,
                point: {
                    events: {
                        click: function (e) {
                            if(e.point.series.options.clickable){
                                var ev = this;
                                _FD.clickEventForTicketList(ev,e.point);
                            }else{
                                return false;
                            }
                        }
                    }
                }
            }, {
                data: data2,
                color: REPORT_COLORS['barChartReal'],
                borderRadius: 5,
                animation: {
                    duration: 1000,
                    easing: 'easeInOutQuart'
                },
                cursor: HelpdeskReports.locals.enable_ticket_list ? 'pointer' : null,
                name: options.second_series,
                clickable: HelpdeskReports.locals.enable_ticket_list,
                point: {
                    events: {
                        click: function (e) {
                            if(e.point.series.options.clickable){
                                var ev = this;
                                _FD.clickEventForTicketList(ev,e.point);
                            }else{
                                return false;
                            }
                        }
                    }
                },
                total: options.total 
            });
            var settings = {
                renderTo: container + "_container",
                height: height,
                xAxisLabel: labels,
                chartData: data_array,
                dataLabels: dataLab,
                sharedTooltip: options.sharedTooltip,
                enableTooltip: options.enableTooltip,
                timeFormat: options.timeFormat,
                suffix: options.suffix,
                minPoint: options.minPoint
            }
            var groupByCharts = new barChart(settings);
            groupByCharts.barChartGraph();
        },
        dataPointLimit: function (){
            return HelpdeskReports.locals.pdf !== undefined ? _FD.DATA_POINT_LIMIT_PDF : _FD.DATA_POINT_LIMIT;
        },
        getCurrentHash: function(hash){
            var current_hash = {}
            var arr = _.keys(hash)
            if(HelpdeskReports.locals.pdf !== undefined && arr.length > _FD.DATA_POINT_LIMIT_PDF) {
                _.each(arr.slice(0,_FD.DATA_POINT_LIMIT_PDF-1), function(i) {
                    current_hash[i] = hash[i];
                });
                if(hash[_FD.GROUP_BY_LIMITING_KEY]!== undefined){
                    current_hash[_FD.GROUP_BY_LIMITING_KEY] = hash[_FD.GROUP_BY_LIMITING_KEY]
                }
                return current_hash;
                
            } else {
                return hash;
            }
        },
        clickEventForTicketList: function (el,point) {
            var active_metric = HelpdeskReports.locals.active_metric;
            if (!(HelpdeskReports.Constants.Glance.percentage_metrics.indexOf(active_metric) < 0 && el.series.name == 'dummy')) {
                var container = el.series.chart.container;
                var group_by = jQuery(container).closest('[data-report="glance-container"]').attr('data-group');
                HelpdeskReports.CoreUtil.actions.hideViewMore();
                var data = {};
                data.label = el.category;
                data.series = el.series.name;
                data.group_by = group_by;
                data.metric = active_metric;

                if(HelpdeskReports.Constants.Glance.percentage_metrics.indexOf(active_metric) > -1){

                    var series = el.series.index;
                    if (series == 1) {
                        data.value = el.y;
                    } else {
                        var index = el.series.data.indexOf(point);
                        var point = parseInt(100 - el.series.chart.series[1].data[index].y);
                        data.value = point;
                    }

                } else{
                    data.value = el.y;
                }

                data.id = HelpdeskReports.locals.chart_hash[active_metric][group_by][el.category].id;

                trigger_event("glance_ticket_list.helpdesk_reports", data);
            }

        },
        renderBucketConditionsGraph: function (hash, metric, bucket) {
            var key = metric + '_BUCKET';
            var bucket_data = HelpdeskReports.Constants.Glance.bucket_data;
            var meta = bucket_data[bucket].meta_data;
            if (hash[key] !== undefined) {

                if(meta.dom_element == "interactions" ) {
                    var tmpl = JST["helpdesk_reports/templates/bucket_conditions_div"]({
                        id: metric.toLowerCase()+'_'+meta.dom_element,
                        title: meta.title + HelpdeskReports.Constants.Glance.metrics[metric].title.toLowerCase(),
                        bucket: bucket
                    });    
                } else{
                    var tmpl = JST["helpdesk_reports/templates/bucket_conditions_div"]({
                        id: metric.toLowerCase()+'_'+meta.dom_element,
                        title: meta.title,
                        bucket: bucket
                    });
                }
                
                if (HelpdeskReports.locals.pdf === undefined){
                    jQuery('#glance_main').append(tmpl);
                } else {
                    jQuery('#'+metric.toLowerCase()).append(tmpl);
                }

                var current_series = bucket_data[bucket].series;
                _FD.constructBucketsChart(hash[key], current_series, meta, metric);
            }
        },
        constructBucketsChart: function (hash, current_series, meta, metric) {
            if (jQuery.isEmptyObject(hash["error"]) && !jQuery.isEmptyObject(hash)) {
                var data_array = [];
                var series = _.keys(current_series);
                for (i = 0; i < series.length; i++) {
                    data_array.push({
                        name: current_series[series[i]],
                        data: _.values(hash[series[i]]).reverse(),
                        legendIndex: i,
                        id: series[i],
                        cursor: HelpdeskReports.locals.enable_ticket_list ? 'pointer' : null,
                        clickable: HelpdeskReports.locals.enable_ticket_list,
                        point: {
                            events: {
                                click: function (e) {
                                    if(e.point.series.options.clickable){
                                        var ev = this;
                                        _FD.clickEventForBucketTicketList(ev);
                                    }else{
                                        return false;
                                    }    
                                }
                            }
                        }
                    });
                }

                var labels = _.keys(hash[series[0]]).reverse();
                var settings = {
                    renderTo: metric.toLowerCase()+'_'+meta.dom_element + '_container',
                    height: meta.chart_height,
                    xAxisLabel: labels,
                    chartData: data_array,
                    xAxis_title: meta.xtitle,
                    yAxis_title: meta.ytitle,
                    legend: meta.legend,
                    pointWidth: meta.pointWidth
                }

                var bucketChart = new barChartMultipleSeries(settings);
                bucketChart.barChartSeriesGraph();

            } else if (jQuery.isEmptyObject(hash)) {
                var msg = 'No data to display';
                var divs = [];
                divs.push(metric.toLowerCase()+'_'+ meta.dom_element + '_container');
                HelpdeskReports.CoreUtil.populateEmptyChart(divs, msg);
            } else if (!jQuery.isEmptyObject(hash["error"])) {
                var msg = 'Something went wrong, please try again';
                var divs = [];
                divs.push(metric.toLowerCase()+'_'+ meta.dom_element + '_container');
                HelpdeskReports.CoreUtil.populateEmptyChart(divs, msg);
            }
        },      
        clickEventForBucketTicketList: function (ev) {
            var container = ev.series.chart.container;
            var bucket_type = jQuery(container).closest('[data-glance-container="bucket"]').data('bucket-name');
            var series_name = ev.series.options.id;
            var series = ev.series.name;
            var hash = HelpdeskReports.locals.chart_hash[HelpdeskReports.locals.active_metric + '_BUCKET'].value_map;
            var data = {
                condition: series_name,
                operator: hash[series_name][ev.category][1],
                value: hash[series_name][ev.category][0],
                series : series,
                x : ev.category,
                y : ev.y
            };

            trigger_event("glance_bucket_ticket_list.helpdesk_reports", data);         

        },
        customFields: function (hash) {
            var locals = HelpdeskReports.locals
            var active_custom_field = locals.active_custom_field;
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
            _FD.constructChartSettings(active_hash, id, false, false);
        },
        renderViewMore: function (el) {
            var attr = jQuery(el).data('group-container');
            jQuery('#view_all_container').data('group',attr);
            var active_metric_hash = HelpdeskReports.locals.chart_hash[HelpdeskReports.locals.active_metric];

            if (!jQuery.isEmptyObject(active_metric_hash[attr])) {
                _FD.constructChartSettings(active_metric_hash, attr, true, false);
            } else {
                console.log('Data not available');
            }

            if (!jQuery('#view_more_wrapper').hasClass('show-all-metrics')) {
                HelpdeskReports.CoreUtil.actions.showViewMore();
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
        },
        mergeDataHash: function (hash) {
            var active_metric = HelpdeskReports.locals.active_metric;
            var group_by = HelpdeskReports.locals.current_group_by;

            if (HelpdeskReports && HelpdeskReports.locals && HelpdeskReports.locals.chart_hash) {
                for (var key in hash) {
                    if (HelpdeskReports.locals.chart_hash.hasOwnProperty(key) && key === active_metric) {
                        for (var i = 0; i < group_by.length; i++) {
                            HelpdeskReports.locals.chart_hash[active_metric][group_by[i]] = hash[key][group_by[i]]; 
                        };
                    } else {
                        HelpdeskReports.locals.chart_hash[key] = hash[key];
                    }
                }
            };
        },
        mergeCustomFieldDataHash: function (hash) {
            var active_metric = HelpdeskReports.locals.active_metric;
            var group_by = HelpdeskReports.locals.custom_fields_group_by;

            if (HelpdeskReports && HelpdeskReports.locals && HelpdeskReports.locals.chart_hash) {
                for (var key in hash[active_metric]) {
                    if (group_by.indexOf(key) > -1 && !HelpdeskReports.locals.chart_hash[active_metric].hasOwnProperty(key)) {
                        HelpdeskReports.locals.chart_hash[active_metric][key] = hash[active_metric][key];
                    }
                }
            };
        },
        constructViewAllTicketsLink: function () {
            var view_all_tmpl = JST["helpdesk_reports/templates/view_all_tickets_template"]();
            jQuery('#view_all_tickets').html(view_all_tmpl);
        }
    };
   return {
        init: function (hash) {
            
            _FD.bindevents();

            if(_.keys(hash).length > 2) {
                _FD.constructSidebar(hash);
            } else {
                _FD.mergeDataHash(hash);
            }
            _FD.constructViewAllTicketsLink();
            _FD.contructCharts(hash);

        },
        customFieldInit: function (hash, flag) {
            if(flag === true) {
                _FD.mergeCustomFieldDataHash(hash);
            }
            _FD.customFields(hash);
        },
        pdf: function (hash) {
            _FD.contructPdfCharts(hash);
        }
    };
})();