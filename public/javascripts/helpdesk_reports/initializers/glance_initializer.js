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
            jQuery(document).on('click.helpdesk_reports.glance', "[data-action='close-drill-down']", function (event) {
                HelpdeskReports.CoreUtil.actions.hideNestedFieldDrillDown();
            });
        },
        actions: {
            viewMoreInit: function (el) {
                _FD.renderViewMore(el);
            },
            
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
            if(jQuery('#glance_sidebar ul li[data-metric="'+metric+'"]').hasClass('disable')){
                if(metric != 'RECEIVED_TICKETS'){
                    HelpdeskReports.locals.active_metric = 'RECEIVED_TICKETS';
                    //Trigger event for refresh
                    trigger_event("set_active_view.helpdesk_reports",{});
                }
                jQuery('#glance_sidebar ul li[data-metric="RECEIVED_TICKETS"]').addClass('active');
            }else{
                jQuery('#glance_sidebar ul li[data-metric="'+metric+'"]').addClass('active');
            }  
        },
        contructCharts: function (hash) {
            var active_metric = HelpdeskReports.locals.active_metric;
            var hash_active = hash[active_metric];
            var group_by = HelpdeskReports.locals.current_group_by;
            var is_historic_present = false;
            HelpdeskReports.CoreUtil.flushCharts();
            jQuery('#glance_main').html('');            

            if (jQuery.isEmptyObject(hash_active['error'])) {
                for (i = 0; i < group_by.length; i++) {
                    if(group_by[i] == "historic_status" && active_metric == "UNRESOLVED_TICKETS"){
                        break;
                    }
                    if(group_by[i] == "status" && active_metric == "UNRESOLVED_TICKETS"){
                       is_historic_present = (typeof hash_active["historic_status"] !== 'undefined');
                    }
                    var group_tmpl = JST["helpdesk_reports/templates/glance_group_by"]({
                        data: group_by[i],
                        metric: active_metric,
                        historic_status: is_historic_present
                    });
                    jQuery('#glance_main').append(group_tmpl);

                    if (!jQuery.isEmptyObject(hash_active[group_by[i]])) {
                        _FD.constructChartSettings(hash_active, group_by[i], false, false, false);
                        if(group_by[i] == "status" && active_metric == "UNRESOLVED_TICKETS"){
                            if(is_historic_present){
                                _FD.constructChartSettings(hash_active, "historic_status", false, false, false);
                                jQuery("#historic_status_container").hide();    
                            }
                            
                        }

                    } else {
                        var msg = I18n.t('helpdesk_reports.no_data_to_display_msg');
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
                var msg = I18n.t('helpdesk_reports.something_went_wrong_msg');
                var div = ["glance_main"];
                HelpdeskReports.CoreUtil.populateEmptyChart(div, msg);
            }

            //Tooltip for historic status
            var date_range = HelpdeskReports.locals.date_range.split('-');
            var end_date;
            if (date_range.length == 2){
                end_date = date_range[1];
            }else{
                end_date = date_range[0];
            }
            var text = 'Status of the tickets at end of ' + end_date;
            jQuery(".historic_tooltip").twipsy({
                html : true,
                placement : "right",
                title : function() { 
                    return text;
              }});


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
                                _FD.constructChartSettings(hash_active, group_by[i], false, active_metric , false);
                            } else {
                                var msg = I18n.t('helpdesk_reports.no_data_to_display_msg');
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
                        var msg = I18n.t('helpdesk_reports.no_data_to_display_msg');
                        var div = [active_metric.toLowerCase()];
                        HelpdeskReports.CoreUtil.populateEmptyChart(div, msg);
                    }
                }
            }

        },
        constructChartSettings: function (hash_active, group_by, view_all, metric,drill_down) {
            var active_metric = metric || HelpdeskReports.locals.active_metric;
            var constants = jQuery.extend({}, HelpdeskReports.Constants.Glance);
            var options = {};

            if(drill_down){
                if(HelpdeskReports.locals.glance_response_hash){
                    var current_hash = _FD.getCurrentHash(hash_active[group_by]); //hash_active[group_by];
                    HelpdeskReports.locals.glance_response_hash = false;
                } else{
                    //when breadcrumb is clicked use the id from breadcrumb state
                    var current_hash;
                    var breadcrumbs = HelpdeskReports.locals.breadcrumb;
                    if(breadcrumbs && HelpdeskReports.locals.breadcrumbs_active){
                         current_hash = _FD.getCurrentHash(hash_active[group_by][breadcrumbs[0].id]); //hash_active[group_by];
                    }else{
                         current_hash = _FD.getCurrentHash(hash_active[group_by][HelpdeskReports.locals.current_custom_field_event.id]); //hash_active[group_by];
                    }
                    HelpdeskReports.locals.breadcrumbs_active = false;
                }
            }else{
                var current_hash = _FD.getCurrentHash(hash_active[group_by]) //hash_active[group_by];    
            }

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
            _FD.renderCommonChart(current_hash, options, group_by, view_all, current_value_array, metric,drill_down);
        },
        renderCommonChart: function (current_hash, options, group_by, view_all, current_value_array, metric,drill_down) {
            var height, data1, data2, dataLab, labels, container;
            var custom_fields = HelpdeskReports.locals.custom_fields_group_by;

            if (view_all) {
                labels = _.keys(current_hash);
                height = _FD.calculateChartheight(labels.length);
                dataLab = current_value_array;
                data1 = this.fillArray(options.value,current_value_array.length);
                data2 = current_value_array;
                container = 'view_all';
            } else if (drill_down) {
                labels = _.keys(current_hash);
                height = _FD.calculateChartheight(labels.length);
                dataLab = current_value_array;
                data1 = this.fillArray(options.value,current_value_array.length);
                data2 = current_value_array;
                container = 'custom_field';
            } else {
                var point_limit = _FD.dataPointLimit();
                if (current_value_array.length > point_limit) {
                    labels = _.first(_.keys(current_hash), point_limit);
                    height = _FD.calculateChartheight(point_limit);
                    dataLab = _.first(current_value_array,point_limit);
                    data1 = this.fillArray(options.value, point_limit);
                    data2 = _.first(current_value_array,point_limit); 

                    //Using data to dynamically update the custom field. 
                    if (custom_fields.indexOf(group_by) < 0){
                        jQuery("[data-group-container='"+ group_by +"']").addClass('active');
                    }else{
                        jQuery("#custom_field_group_by [data-container='view-more']").data("group-container", group_by).addClass('active');
                    }

                } else {
                    labels = _.keys(current_hash);
                    height = _FD.calculateChartheight(labels.length);
                    dataLab = current_value_array;
                    data1 = this.fillArray(options.value,current_value_array.length);
                    data2 = current_value_array;

                    if (custom_fields.indexOf(group_by) < 0){
                        jQuery("[data-group-container='"+ group_by +"']").removeClass('active');
                    }else{
                        jQuery("#custom_field_group_by [data-container='view-more']").data("group-container", group_by).removeClass('active');
                    }

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
                //Added the group attribute to view_all_container using jquery data, so to retrieve we use
                //data function , for others we use attr to get and set. This is done because attr was not updating
                //properly dynamically
                var group_by = "";
                if(container && jQuery(container).parent().attr('id') == "view_all_container"){
                    group_by = jQuery(container).closest('[data-report="glance-container"]').data('group');
                } else{
                    group_by = jQuery(container).closest('[data-report="glance-container"]').attr('data-group');
                }
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
                
                if(jQuery(container).parent().attr('id') == 'custom_field_container'){
                     var data_id = jQuery(container).closest('[data-report="glance-container"]').attr('data-id');
                     data.id = HelpdeskReports.locals.chart_hash[active_metric][group_by][data_id][el.category].id;
                     data.base_chart_click = false; 
                } else{
                    data.id = HelpdeskReports.locals.chart_hash[active_metric][group_by][el.category].id; 
                    data.base_chart_click = true;                   
                }

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
                        title: meta.title + HelpdeskReports.Constants.Glance.metrics[metric].name.toLowerCase(),
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
                    var legend_name = current_series[series[i]]+"<br/>"+I18n.t('helpdesk_reports.average_interactions',{count: hash['average_interactions'][series[i]]});
                    data_array.push({
                        name: legend_name, //for complex formatting use highcharts format string or labelFormatter callback
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
                var msg = I18n.t('helpdesk_reports.no_data_to_display_msg');
                var divs = [];
                divs.push(metric.toLowerCase()+'_'+ meta.dom_element + '_container');
                HelpdeskReports.CoreUtil.populateEmptyChart(divs, msg);
            } else if (!jQuery.isEmptyObject(hash["error"])) {
                var msg = I18n.t('helpdesk_reports.no_data_to_display_msg');
                var divs = [];
                divs.push(metric.toLowerCase()+'_'+ meta.dom_element + '_container');
                HelpdeskReports.CoreUtil.populateEmptyChart(divs, msg);
            }
        },      
        clickEventForBucketTicketList: function (ev) {
            var container = ev.series.chart.container;
            var bucket_type = jQuery(container).closest('[data-glance-container="bucket"]').data('bucket-name');
            var series_name = ev.series.options.id;
            var series_index = ev.series.index;
            var hash = HelpdeskReports.locals.chart_hash[HelpdeskReports.locals.active_metric + '_BUCKET'].value_map;
            var data = {
                condition: series_name,
                operator: hash[series_name][ev.category][1],
                value: hash[series_name][ev.category][0],
                series_index : series_index,
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
                var msg = I18n.t('helpdesk_reports.no_data_to_display_msg');
                var div = [active_custom_field + '_container'];
                HelpdeskReports.CoreUtil.populateEmptyChart(div, msg);
            
            } else if (!jQuery.isEmptyObject(hash[locals.active_metric]["error"])) {
                var msg = I18n.t('helpdesk_reports.something_went_wrong_msg');
                var div = [active_custom_field + '_container'];
                HelpdeskReports.CoreUtil.populateEmptyChart(div, msg);
            
            }
        },
        customNestedFields : function(hash){
            var locals = HelpdeskReports.locals
            var active_custom_field = locals.active_custom_field;
            if (jQuery.isEmptyObject(hash[locals.active_metric]["error"]) && !jQuery.isEmptyObject(hash[locals.active_metric])) {
                _FD.renderCustomFieldChart(hash, 'custom_field');

            } else if (jQuery.isEmptyObject(hash[locals.active_metric])) {
                var msg = I18n.t('helpdesk_reports.no_data_to_display_msg');
                var div = [active_custom_field + '_container'];
                HelpdeskReports.CoreUtil.populateEmptyChart(div, msg);
            
            } else if (!jQuery.isEmptyObject(hash[locals.active_metric]["error"])) {
                var msg = I18n.t('helpdesk_reports.something_went_wrong_msg');
                var div = [active_custom_field + '_container'];
                HelpdeskReports.CoreUtil.populateEmptyChart(div, msg);
            
            }
             if (!jQuery('#custom_field_wrapper').hasClass('show-drill-down')) {
                HelpdeskReports.CoreUtil.actions.showNestedFieldDrillDown();
            }
        },
        renderCustomFieldChart: function(hash, id) {
            var custom_field_chart  = jQuery('#' + id + '_container').highcharts();
            var active_metric = HelpdeskReports.locals.active_metric;
            var active_hash = hash[active_metric];
            if (custom_field_chart !== undefined) {
                custom_field_chart.destroy();
            }
            if( id == 'custom_field'){
                _FD.constructChartSettings(active_hash,HelpdeskReports.locals.nested_group_by, false, false, true);
            } else{
                _FD.constructChartSettings(active_hash, id, false, false, false);
            }
        },
        renderViewMore: function (el) {
            var attr = jQuery(el).data('group-container');
            jQuery('#view_all_container').data('group',attr);
            var active_metric_hash = HelpdeskReports.locals.chart_hash[HelpdeskReports.locals.active_metric];

            if (!jQuery.isEmptyObject(active_metric_hash[attr])) {
                _FD.constructChartSettings(active_metric_hash, attr, true, false , false);
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
            //if the metric is unresolved, extra historic status is added in group by
            if(active_metric == "UNRESOLVED_TICKETS"){
                group_by.push("historic_status")
            }
                
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
        mergeCustomNestedFieldDataHash: function (hash) {
            var active_metric = HelpdeskReports.locals.active_metric;
            var group_by = HelpdeskReports.locals.custom_fields_group_by;
            var current_custom_field_id = HelpdeskReports.locals.current_custom_field_event.id;

            if (HelpdeskReports && HelpdeskReports.locals && HelpdeskReports.locals.chart_hash) {
                for (var key in hash[active_metric]) {
                    if (group_by.indexOf(key) > -1 || HelpdeskReports.locals.nested_group_by == key) {
                        if(HelpdeskReports.locals.chart_hash[active_metric][key] == undefined){
                            HelpdeskReports.locals.chart_hash[active_metric][key] = {};
                        }
                        HelpdeskReports.locals.chart_hash[active_metric][key][current_custom_field_id] = hash[active_metric][key];
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
        customNestedFieldInit: function (hash, flag) {
            if(flag === true) {
                _FD.mergeCustomNestedFieldDataHash(hash);
            }
            _FD.customNestedFields(hash);
        },
        pdf: function (hash) {
            _FD.contructPdfCharts(hash);
        }
    };
})();