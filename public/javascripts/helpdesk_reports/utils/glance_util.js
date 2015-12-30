HelpdeskReports.ReportUtil = HelpdeskReports.ReportUtil || {};

HelpdeskReports.ReportUtil.Glance = (function () {
    var _FD = {
        bindEvents: function () {
            jQuery('#reports_wrapper').on('click.helpdesk_reports', "[data-action='reports-submit']", function () {
                _FD.actions.submitReports();
            });

            jQuery('#reports_wrapper').on('click.helpdesk_reports', '#glance_sidebar ul li:not(".active"):not(".disable")', function() {
                var flag = HelpdeskReports.locals.ajaxContainer;
                if (flag == false) {
                    HelpdeskReports.locals.ajaxContainer = true;
                    _FD.actions.submitActiveMetric(this);
                }
            });

            jQuery('#reports_wrapper').on('click.helpdesk_reports', '[data-ticket="view_all"]', function() {
                _FD.actions.viewAllTickets(this);
            });

            jQuery('#reports_wrapper').on('change.helpdesk_reports', '#custom_field_group_by select', function() {
                var flag = HelpdeskReports.locals.customFieldFlag;
                if (flag == false) {
                    HelpdeskReports.locals.customFieldFlag = true;
                    _FD.actions.submitCustomField(this);
                }
            });

            jQuery(document).on("glance_ticket_list.helpdesk_reports", function (ev, data) {
                var flag = HelpdeskReports.locals.ticket_list_flag;
                if (flag == false) {
                    HelpdeskReports.locals.ticket_list_flag = true;
                    _FD.getTicketListTitle(data);
                    _FD.actions.ticketListEvent(data);
                }
            });

            jQuery(document).on("glance_bucket_ticket_list.helpdesk_reports", function (ev, data) {
                var flag = HelpdeskReports.locals.ticket_list_flag;
                if (flag == false) {
                    HelpdeskReports.locals.ticket_list_flag = true;
                     _FD.getBucketTicketListTitle(data);
                    _FD.actions.bucketTicketListEvent(data);
                }
            });

            _FD.actions.setAjaxContainer();
            _FD.actions.setCustomFieldFlag();
        },
        
        getTicketListTitle : function(data){
                var fields_hash = HelpdeskReports.locals.field_name_mapping;
                var active_metric = HelpdeskReports.locals.active_metric;
                var ticketListTitle = HelpdeskReports.Constants.Glance.metrics[active_metric].title;
                var group_by = data['group_by'];
               
                var val = data['value'];
                
                if(_FD.constants.time_metrics.indexOf(active_metric) > -1){
                    val = _FD.core.timeMetricConversion(val);
                }
                if(_FD.constants.percentage_metrics.indexOf(active_metric) > -1){
                    val = _FD.core.addsuffix(val);
                    ticketListTitle += " by " +  fields_hash[group_by].toLowerCase();
                }else{
                    ticketListTitle += " split by " +  fields_hash[group_by].toLowerCase();
                }
                var value = data['label'] + ' : ' + val;
                _FD.core.actions.showTicketList(ticketListTitle,value);
        },

        getBucketTicketListTitle : function(data){
                var title = "";
                title = data.y  + ' Tickets with ' + data.x + ' ' + data.series;
                _FD.core.actions.showTicketList(title);
        },

        actions: {
            submitReports: function () {
                var metric = HelpdeskReports.locals.active_metric;
                
                HelpdeskReports.locals.params = HelpdeskReports.locals.default_params.slice();

                if (_FD.constants.bucket_condition_metrics.indexOf(metric) > -1) {
                    var bucket_conditions = _FD.constants.metrics[metric].bucket;
                    var bucket_param = _FD.getBucketConditions(HelpdeskReports.locals.params[0], metric, bucket_conditions);
                    HelpdeskReports.locals.params.push(bucket_param);
                }
                                
                var flag = _FD.core.refreshReports();
                
                if(flag) {
                    _FD.setGroupByInParams();
                    _FD.core.resetAndGenerate();
                    HelpdeskReports.locals.visited_metrics = [];
                    HelpdeskReports.locals.visited_metrics.push(metric);
                } else {
                    _FD.actions.setDefaultOnFail(metric);
                }
            },
            submitActiveMetric: function (active) {
                var prev_metric = HelpdeskReports.locals.active_metric;
                var active_metric = jQuery(active).data('metric');
                _FD.setActiveMetric(active_metric);

                var group_by = _FD.core.setDefaultGroupByOptions(active_metric);
                if (HelpdeskReports.locals.custom_fields_group_by.length) {
                    group_by.push(HelpdeskReports.locals.custom_fields_group_by[0]);
                }
                HelpdeskReports.locals.current_group_by = group_by;

                jQuery('#glance_sidebar li').removeClass('active');
                _FD.core.actions.hideViewMore();
                _FD.core.actions.hideTicketList();
                jQuery('li[data-metric="'+ active_metric +'"]').addClass('active');
                jQuery('#glance_chart_wrapper .loading-bar').removeClass('hide');

                if(HelpdeskReports.locals.visited_metrics.indexOf(HelpdeskReports.locals.active_metric) > -1) {
                    HelpdeskReports.ChartsInitializer.Glance.init(HelpdeskReports.locals.chart_hash);
                    jQuery('#glance_chart_wrapper .loading-bar').addClass('hide');
                    jQuery('#view_all_tickets').show();
                    _FD.actions.setAjaxContainer();

                } else {
                    _FD.constructRightPaneParams(active_metric, group_by);
                }
                _FD.actions.setSolutionLinkUrl(active_metric);
            },
            setSolutionLinkUrl : function(active_metric){
                //Set the solution url for the active metric
                jQuery(".glance-chart #solution_link").attr('href',_FD.constants.metrics[active_metric].solution_url);
            },
            setDefaultOnFail: function (metric) {
                _FD.setActiveMetric(metric);
                _FD.actions.setAjaxContainer();
            },
            submitCustomField: function (active) {
                _FD.core.actions.hideViewMore();
                _FD.core.actions.hideTicketList();
                _FD.core.actions.hideReportTypeMenu();
                _FD.core.actions.closeFilterMenu();
                var val  = jQuery(active).select2('val');
                HelpdeskReports.locals.active_custom_field = val;
                jQuery('#custom_field_group_by .half-container').attr('id', val + '_container');
                jQuery('#custom_field_group_by .half-container').attr('data-group', val);
                jQuery("#custom_field_group_by [data-container='view-more']").data("group-container", val);
                if (!HelpdeskReports.locals.chart_hash[HelpdeskReports.locals.active_metric].hasOwnProperty(val)) {
                    _FD.constructCustomFieldParams(val);
                } else {
                    HelpdeskReports.ChartsInitializer.Glance.customFieldInit(HelpdeskReports.locals.chart_hash, false);
                    _FD.actions.setCustomFieldFlag();
                }
            },
            setAjaxContainer: function () {
                HelpdeskReports.locals.ajaxContainer = false;
            },
            setCustomFieldFlag: function () {
               HelpdeskReports.locals.customFieldFlag = false; 
            },
            viewAllTickets: function (el) {
                var metric = HelpdeskReports.locals.active_metric;
                var conditions = [];
                var ticket_count = jQuery("li[data-metric='" + metric + "'] .ticket-count").html();
                if (_FD.constants.percentage_metrics.indexOf(metric) > -1) {

                    var value = jQuery(el).data('sla');
                    var hash = {
                        condition: _FD.constants.metrics[metric].ticket_list_metric,
                        operator: 'is',
                        value: value
                    }
                    conditions.push(hash);
                    if(jQuery(el).hasClass('compliant')){
                         _FD.core.actions.showTicketList(_FD.constants.metrics[metric].ticket_list_complaint_title,ticket_count);
                    }else if(jQuery(el).hasClass('violated')){
                        //Calculate violated percentage
                        var calc = ticket_count.substring(0,ticket_count.length-1);
                        var percent = calc != undefined ? 100 - parseInt(calc) : calc; 
                         _FD.core.actions.showTicketList(_FD.constants.metrics[metric].ticket_list_violated_title,_FD.core.addsuffix(percent));
                    }
                } else if(_FD.constants.time_metrics.indexOf(metric) > -1){
                    _FD.core.actions.showTicketList(_FD.constants.metrics[metric].ticket_list_title,ticket_count);
                } else{
                    var general_result = HelpdeskReports.locals.chart_hash[metric].general;
                    if(general_result != undefined){
                         _FD.core.actions.showTicketList(_FD.constants.metrics[metric].ticket_list_title,general_result.metric_result);
                    }else{
                        _FD.core.actions.showTicketList(_FD.constants.metrics[metric].ticket_list_title,"NA");
                    }
                }
                

                var bucket_flag = false;

                
                _FD.constructTicketListParams(conditions, metric, bucket_flag);
            },
            ticketListEvent: function (data) {

                var active_metric = data.metric;
                var conditions = [];

                var main_condition = _FD.actions.constructMainListCondition(data.group_by, data.label, data.id);

                if(!jQuery.isEmptyObject(main_condition)) {
                    conditions.push(main_condition);
                }

                if (_FD.constants.percentage_metrics.indexOf(active_metric) > -1) {

                    var supplement_condition = {
                        condition : _FD.constants.metrics[active_metric].ticket_list_metric,
                        operator : 'is',
                        value : data.series === 'compliant' ? false : true 
                    };
                    conditions.push(supplement_condition);
                    
                }
                var bucket_flag = false;
                _FD.constructTicketListParams(conditions, active_metric, bucket_flag);

            },
            bucketTicketListEvent: function (data) {
                var conditions = [];
                conditions.push(data);
                var bucket_flag = true;
                _FD.constructTicketListParams(conditions, HelpdeskReports.locals.active_metric, bucket_flag);
            },  
            constructMainListCondition: function (group_by, label, id) {
                var list_hash = {};
                var hash_group_by = HelpdeskReports.locals.report_options_hash[group_by];

                if (hash_group_by.hasOwnProperty(id)) {
                    list_hash = {
                        condition : group_by,
                        operator: 'eql',
                        value: id.toString()
                    }
                } else {
                    if(_.keys(hash_group_by).length){
                        list_hash = {
                            condition : group_by,
                            operator: 'is_not_in',
                            value: _.keys(hash_group_by).join()
                        }
                    }
                }

                return list_hash;
            }
        },
        setGroupByInParams: function () {
            jQuery.each(HelpdeskReports.locals.params, function (index, value) {
                if (value.bucket == false && value.metric == HelpdeskReports.locals.active_metric) {
                    value.group_by = HelpdeskReports.locals.current_group_by;
                } else {
                    value.group_by = [];
                }
            });
        },
        constructRightPaneParams: function (metric, group_by) {
            var date = HelpdeskReports.locals.date_range;

            var merge_hash = {
                date_range: date,
                filter: HelpdeskReports.locals.query_hash,
                group_by: group_by,
                metric: metric,
                reference: false
            }
            var param = jQuery.extend({}, _FD.constants.params, merge_hash);
            var current_params = [];
            current_params.push(param);
            
            if (_FD.constants.bucket_condition_metrics.indexOf(metric) > -1) {
                var bucket_conditions = _FD.constants.metrics[metric].bucket;
                var bucket_param = _FD.getBucketConditions(current_params[0], metric, bucket_conditions);
                current_params.push(bucket_param);
            }
            _FD.renderRightPane(current_params);
        },
        renderRightPane: function (params) {
            HelpdeskReports.CoreUtil.scrollToReports();
            var opts = {
                url: _FD.core.CONST.base_url + HelpdeskReports.locals.report_type + '/fetch_active_metric',
                type: 'POST',
                dataType: 'json',
                contentType: 'application/json',
                data: Browser.stringify(params),
                timeout: _FD.core.timeouts.glance_right_pane,
                success: function (data) {
                    HelpdeskReports.ChartsInitializer.Glance.init(data);
                    jQuery('#glance_chart_wrapper .loading-bar').addClass('hide');
                    jQuery('#view_all_tickets').show();
                    HelpdeskReports.locals.visited_metrics.push(HelpdeskReports.locals.active_metric);
                    _FD.actions.setAjaxContainer();
                },
                error: function (data) {
                    var text = "Something went wrong, please try again";
                    HelpdeskReports.CoreUtil.populateEmptyChart(["glance_main"], text);
                    jQuery('#glance_chart_wrapper .loading-bar').addClass('hide');
                    jQuery('#view_all_tickets').hide();
                    _FD.actions.setAjaxContainer();
                }
            }
            _FD.core.makeAjaxRequest(opts);
        },
        constructCustomFieldParams: function (field) {
            var date = HelpdeskReports.locals.date_range;

            var merge_hash = {
                date_range: date,
                filter: HelpdeskReports.locals.query_hash,
                group_by: [],
                metric: HelpdeskReports.locals.active_metric,
                reference: false
            }
            var param = jQuery.extend({}, _FD.constants.params, merge_hash);
            param.group_by.push(field);

            var current_params = [];
            current_params.push(param);

            _FD.customFieldJSON(current_params);
        },
        customFieldJSON: function (params) {
            var opts = {
                url: _FD.core.CONST.base_url + HelpdeskReports.locals.report_type + '/fetch_active_metric',
                type: 'POST',
                dataType: 'json',
                contentType: 'application/json',
                data: Browser.stringify(params),
                timeout: _FD.core.timeouts.custom_field,
                success: function (data) {
                    HelpdeskReports.ChartsInitializer.Glance.customFieldInit(data, true);
                    _FD.actions.setCustomFieldFlag();
                },
                error: function (data) {
                    var text = "Something went wrong, please try again";
                    HelpdeskReports.CoreUtil.populateEmptyChart([HelpdeskReports.locals.active_custom_field + "_container"], text);
                    _FD.actions.setCustomFieldFlag();
                }
            }
            _FD.core.makeAjaxRequest(opts);
        },
        constructTicketListParams: function (conditions, metric, bucket_flag) {
            HelpdeskReports.locals.list_params = [];
            var list_params = HelpdeskReports.locals.list_params;

            var list_hash = {
                bucket: bucket_flag ? true : false,
                date_range: HelpdeskReports.locals.date_range,
                filter: HelpdeskReports.locals.query_hash,
                list: true,
                list_conditions: conditions,
                metric: metric
            }

            var hash = jQuery.extend({}, _FD.constants.params, list_hash);
            list_params.push(hash);

            _FD.core.fetchTickets(list_params);

        },
        setDefaultValues: function () {
            var current_params = [];
            var date = _FD.core.setReportFilters();
            var active_metric = _FD.constants.default_metric;
            _FD.setActiveMetric(active_metric);
            jQuery.each(_.keys(_FD.constants.metrics), function (index, value) {
                var merge_hash = {
                    date_range: date,
                    filter: [],
                    group_by: [],
                    metric: value
                }
                var param = jQuery.extend({}, _FD.constants.params, merge_hash);
                current_params.push(param);
            });

            HelpdeskReports.locals.default_params = current_params.slice();
            HelpdeskReports.locals.visited_metrics = [];

            _FD.actions.submitReports();
        },
        setActiveMetric: function (metric) {
            HelpdeskReports.locals.active_metric = metric;
        },
        getBucketConditions: function (param, metric, bucket_conditions) {
            var bucket_param = {};
            var bucket_hash = {};
            bucket_hash = {
                metric : metric,
                bucket : true,
                bucket_conditions : bucket_conditions,
                reference : false,
                group_by : []
            }
            bucket_param = jQuery.extend({},param, bucket_hash);
            return bucket_param;
        }
    };
    return {
        init: function () {
            _FD.core = HelpdeskReports.CoreUtil;
            _FD.constants = jQuery.extend({}, HelpdeskReports.Constants.Glance);
            _FD.bindEvents();
            _FD.core.ATTACH_DEFAULT_FILTER = true;
            _FD.setDefaultValues();
            
        }
    };
})();