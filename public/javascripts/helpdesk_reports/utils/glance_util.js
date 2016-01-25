HelpdeskReports.ReportUtil = HelpdeskReports.ReportUtil || {};

HelpdeskReports.ReportUtil.Glance = (function () {
    var _FD = {
        bindEvents: function () {
            jQuery('#reports_wrapper').on('click.helpdesk_reports', "[data-action='reports-submit']", function () {
                _FD.actions.submitReports();
            });
            jQuery(document).on('click.helpdesk_reports.glance', "[data-action='nav-drill-down']", function (event) {
                _FD.actions.navBack();
                //Set title for the drill down
                jQuery("#view_title_custom").html(HelpdeskReports.locals.breadcrumb[0].title);
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
                var locals = HelpdeskReports.locals;
                var flag = HelpdeskReports.locals.ticket_list_flag;
                if (flag == false) {
                    var is_last_level = false;
                    var ticket_list_for_drill_down = false;
                    var group_by = data.group_by;
                    var custom_field_hash = HelpdeskReports.locals.custom_fields_group_by;
                    if(HelpdeskReports.locals.breadcrumb == undefined){
                        HelpdeskReports.locals.breadcrumb = [];
                    }
                    
                    if(data.base_chart_click){
                        HelpdeskReports.locals.breadcrumb = [];
                        _FD.clearNestedFieldCondition();
                    }else{
                        ticket_list_for_drill_down = true;
                    }
                    var breadcrumbs = HelpdeskReports.locals.breadcrumb;
                    //only for non none entries
                    if(data.id != null){
                        //Check for custom field group by
                        if(jQuery.inArray(group_by,custom_field_hash) != -1 || group_by == HelpdeskReports.locals.nested_group_by){
                            //Check for nested field
                            var report_field_hash = HelpdeskReports.locals.report_field_hash;
                            is_last_level = _FD.isLastLevelInNestedField(group_by);
                            //Set the data to locals object
                            HelpdeskReports.locals.current_custom_field_event = data;
                            if(!is_last_level){
                                
                                if(breadcrumbs && breadcrumbs.length == 1){
                                    //show the back link
                                    jQuery("[data-action='nav-drill-down']").show();
                                }else if(breadcrumbs && breadcrumbs.length == 0){
                                    jQuery("[data-action='nav-drill-down']").hide();
                                    //Add the level to breadcrumb
                                    var breadcrumb = {
                                        id : data.id,
                                        title : _FD.getNestedDrillDownTitle(data)
                                    };
                                    HelpdeskReports.locals.breadcrumb.push(breadcrumb);
                                }

                                //Set title for the drill down
                                jQuery("#view_title_custom").html(_FD.getNestedDrillDownTitle(data));

                                jQuery('#custom_field_container').attr('data-group', locals.nested_group_by);
                                jQuery('#custom_field_container').attr('data-id', data.id);
                                HelpdeskReports.locals.active_custom_field = locals.nested_group_by;
                                _FD.constructDrillDownParams();
                                if (!(HelpdeskReports.locals.chart_hash[HelpdeskReports.locals.active_metric][locals.nested_group_by] && HelpdeskReports.locals.chart_hash[HelpdeskReports.locals.active_metric][locals.nested_group_by].hasOwnProperty(data.id))) {
                                    _FD.constructCustomFieldParams(locals.nested_group_by,true);
                                } else {
                                    HelpdeskReports.ChartsInitializer.Glance.customNestedFieldInit(HelpdeskReports.locals.chart_hash, false);
                                    _FD.actions.setCustomFieldFlag();
                                }
                            }
                            
                        }else{
                            is_last_level = true;  
                        }
                    }else{
                        is_last_level = true;
                    }
                    if(is_last_level){
                        HelpdeskReports.locals.ticket_list_flag = true;
                        _FD.getTicketListTitle(data);
                        _FD.actions.ticketListEvent(data,ticket_list_for_drill_down); 
                    }
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

            jQuery(document).on("glance_empty_default_view.helpdesk_reports", function (ev, data) {
                     var el = jQuery('#glance_sidebar ul li[data-metric="RECEIVED_TICKETS"]');
                    _FD.actions.submitActiveMetric(el);
            });

            _FD.actions.setAjaxContainer();
            _FD.actions.setCustomFieldFlag();
        },
        isLastLevelInNestedField : function(group_by){
            //Check for nested field
            var locals = HelpdeskReports.locals;
            var report_field_hash = locals.report_field_hash;
            var custom_field_hash = locals.custom_field_hash;

            var is_last_level = true;
            if(report_field_hash[group_by] != undefined){
                if(report_field_hash[group_by].container == "multi_select"){
                    return true;
                }
            }

            for (var hash in custom_field_hash) {
              if (report_field_hash.hasOwnProperty(hash)) {
                    var group = report_field_hash[hash];
                            if(group['container'] == 'nested_field'){
                                 //check the current node before traversing the children
                                if(group.condition == group_by){
                                    if(group['nested_fields'].length > 0){
                                        is_last_level = false;   
                                        locals.nested_group_by = group['nested_fields'][0].condition;
                                        break; 
                                    }
                                }
                                else{
                                        //group will be active
                                        var no_of_levels = group['nested_fields'].length;
                                         //Only two levels
                                        if( no_of_levels == 2){
                                            var child_group_1 = group['nested_fields'][0];
                                            if(child_group_1.condition == group_by){
                                                locals.nested_group_by = group['nested_fields'][1].condition;
                                                is_last_level = false;
                                                break;
                                            }   
                                        } 
                                        if( no_of_levels == 1){
                                            var child_group = group['nested_fields'][0];
                                            if(child_group.condition == group_by){
                                                is_last_level = true;
                                                break;
                                            }
                                        }
                                }
                         }
                }
            }
            return is_last_level;
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
                }
                group_type = I18n.t(fields_hash[group_by].toLowerCase(),{scope: 'helpdesk_reports.chart_title', defaultValue: fields_hash[group_by].toLowerCase() });
                ticketListTitle = I18n.t(ticketListTitle,{group_by: group_type});
                var value = data['label'] + ' : ' + val;
                _FD.core.actions.showTicketList(ticketListTitle,value);
        },
        getNestedDrillDownTitle : function(data){
                var fields_hash = HelpdeskReports.locals.field_name_mapping;
                var active_metric = HelpdeskReports.locals.active_metric;
                var drillDownTitleKey = HelpdeskReports.Constants.Glance.metrics[active_metric].title;
                var group_by = data['group_by'];
               
                var val = data['value'];
                
                if(_FD.constants.time_metrics.indexOf(active_metric) > -1){
                    val = _FD.core.timeMetricConversion(val);
                }
                if(_FD.constants.percentage_metrics.indexOf(active_metric) > -1){
                    val = _FD.core.addsuffix(val);
                }
                var drillDownTitle = I18n.t(drillDownTitleKey, {group_by: fields_hash[group_by].toLowerCase()});
                var value = drillDownTitle + " : " + data['label'];
                return value;
        },
        getBucketTicketListTitle : function(data){
                var title = "";
                if (data.series_index == 0){
                    title = I18n.t('helpdesk_reports.chart_title.tooltip.tickets_with_agent_responses',{ticket_count: data.y, count: data.x});
                }
                else{
                    title = I18n.t('helpdesk_reports.chart_title.tooltip.tickets_with_customer_responses',{ticket_count: data.y, count: data.x});
                }
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
                    var group_param = _FD.getGroupByConditions(HelpdeskReports.locals.params[0], metric);
                    HelpdeskReports.locals.params.push(group_param);
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
                jQuery(".glance-chart .active-metric-title").html(_FD.constants.metrics[active_metric].name);
            },
            setDefaultOnFail: function (metric) {
                _FD.setActiveMetric(metric);
                _FD.actions.setAjaxContainer();
            },
            submitCustomField: function (active) {
                _FD.core.actions.hideViewMore();
                _FD.core.actions.hideNestedFieldDrillDown();
                _FD.core.actions.hideTicketList();
                _FD.core.actions.hideReportTypeMenu();
                _FD.core.actions.closeFilterMenu();
                var val  = jQuery(active).select2('val');
                HelpdeskReports.locals.active_custom_field = val;
                jQuery('#custom_field_group_by .half-container').attr('id', val + '_container');
                jQuery('#custom_field_group_by .half-container').attr('data-group', val);
                if (!HelpdeskReports.locals.chart_hash[HelpdeskReports.locals.active_metric].hasOwnProperty(val)) {
                    _FD.constructCustomFieldParams(val,false);
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
            submitNestedFieldDrillDown : function(){

                if (!jQuery.isEmptyObject(active_metric_hash[attr])) {
                    _FD.constructChartSettings(active_metric_hash, attr, true, false);
                } else {
                    console.log('Data not available');
                }

                if (!jQuery('#custom_field_wrapper').hasClass('show-drill-down')) {
                    HelpdeskReports.CoreUtil.actions.showViewMore();
                }  
            },
            ticketListEvent: function (data,ticket_list_for_drill_down) {

                var active_metric = data.metric;
                var conditions = [];
                
                if(ticket_list_for_drill_down) {
                   conditions = conditions.concat(HelpdeskReports.locals.drill_down_hash);
                   HelpdeskReports.locals.drill_down_hash = [];
                } 
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
            },
            navBack : function(){
                var breadcrumbs = HelpdeskReports.locals.breadcrumb;
                if(breadcrumbs.length == 1){
                    var state = breadcrumbs[0];
                    HelpdeskReports.locals.breadcrumbs_active = true;
                    jQuery("#view_title_custom").html(_FD.getNestedDrillDownTitle(HelpdeskReports.locals.current_custom_field_event));

                    //Get last group by from event data
                    jQuery('#custom_field_container').attr('data-group', HelpdeskReports.locals.current_custom_field_event.group_by);
                    jQuery('#custom_field_container').attr('data-id', state.id);
                    HelpdeskReports.locals.active_custom_field = state.group;
                    HelpdeskReports.locals.nested_group_by = HelpdeskReports.locals.current_custom_field_event.group_by;
                    HelpdeskReports.ChartsInitializer.Glance.customNestedFieldInit(HelpdeskReports.locals.chart_hash, false);
                     _FD.actions.setCustomFieldFlag();
                     //breadcrumbs.pop();
                    jQuery("[data-action='nav-drill-down']").hide();
                }else{
                    jQuery("[data-action='nav-drill-down']").hide();
                }

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
                    var text = I18n.t('helpdesk_reports.something_went_wrong_msg');
                    HelpdeskReports.CoreUtil.populateEmptyChart(["glance_main"], text);
                    jQuery('#glance_chart_wrapper .loading-bar').addClass('hide');
                    jQuery('#view_all_tickets').hide();
                    _FD.actions.setAjaxContainer();
                }
            }
            _FD.core.makeAjaxRequest(opts);
        }, 
        constructDrillDownParams: function(){
            var date = HelpdeskReports.locals.date_range;
            merge_drill_hash = {};
                //Add the current group by to filter
                //If none,join other filters
            if(HelpdeskReports.locals.current_custom_field_event.id == null){
                var list_hash = {};
                var hash_group_by = HelpdeskReports.locals.report_options_hash[HelpdeskReports.locals.current_custom_field_event.group_by];

                if(_.keys(hash_group_by).length){
                    list_hash = {
                        condition : HelpdeskReports.locals.current_custom_field_event.group_by,
                        operator: 'is_not_in',
                        value: _.keys(hash_group_by).join()
                    }
                }
                HelpdeskReports.locals.query_hash.push(list_hash);
                
            } else{
                //Override the groupby if already added
                var found = false;
                var query_hash = HelpdeskReports.locals.query_hash;
                for( i = 0; i<query_hash.length ; i++){
                    var query = query_hash[i];
                    if(query.condition == HelpdeskReports.locals.current_custom_field_event.group_by){
                        found = true;
                        break;
                    }
                }
                if(found){
                    HelpdeskReports.locals.query_hash[i].value = HelpdeskReports.locals.current_custom_field_event.id;
                }else{
                    HelpdeskReports.locals.query_hash.push({
                        condition: HelpdeskReports.locals.current_custom_field_event.group_by,
                        operator: 'eql',
                        value: HelpdeskReports.locals.current_custom_field_event.id,
                        nested_field_filter : true
                    });    
                }
                
            }
                merge_drill_hash = {
                    date_range: date,
                    filter: HelpdeskReports.locals.query_hash,
                    group_by: [],
                    metric: HelpdeskReports.locals.active_metric,
                    reference: false
                }
        },
        constructCustomFieldParams: function (field,isDrillDown) {
            var date = HelpdeskReports.locals.date_range;
            var merge_hash = {};
            
            if(isDrillDown){
                merge_hash = merge_drill_hash;
            }else{
                merge_hash = {
                    date_range: date,
                    filter: HelpdeskReports.locals.query_hash,
                    group_by: [],
                    metric: HelpdeskReports.locals.active_metric,
                    reference: false
                }    
            }
        
            var param = jQuery.extend({}, _FD.constants.params, merge_hash);
            param.group_by.push(field);

            var current_params = [];
            current_params.push(param);

            _FD.customFieldJSON(current_params,isDrillDown);
        },
        clearNestedFieldCondition : function() {
            //Remove any nested field filter conditions added previously
            for(i = HelpdeskReports.locals.query_hash.length ;i>0 ;i--){
                var index = HelpdeskReports.locals.query_hash.length - i; 
                var filter = HelpdeskReports.locals.query_hash[index];
                if(filter.nested_field_filter != undefined && filter.nested_field_filter){
                    HelpdeskReports.locals.query_hash.splice(index,1);
                }
            }
        },
        customFieldJSON: function (params,isDrillDown) {
            var opts = {
                url: _FD.core.CONST.base_url + HelpdeskReports.locals.report_type + '/fetch_active_metric',
                type: 'POST',
                dataType: 'json',
                contentType: 'application/json',
                data: Browser.stringify(params),
                timeout: _FD.core.timeouts.custom_field,
                success: function (data) {
                    if(isDrillDown){
                        HelpdeskReports.locals.glance_response_hash = true;
                        HelpdeskReports.ChartsInitializer.Glance.customNestedFieldInit(data, true);
                    }else{
                        HelpdeskReports.ChartsInitializer.Glance.customFieldInit(data, true);
                        _FD.actions.setCustomFieldFlag();    
                    }
                },
                error: function (data) {
                    var text = I18n.t('helpdesk_reports.something_went_wrong_msg');
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
           jQuery.each(_FD.constants.template_metrics, function (index, value) {
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
        getGroupByConditions: function (param, metric){
            var group_param = {};
            var group_hash = {};
            var group_by = HelpdeskReports.locals.current_group_by;
            group_hash = {
                metric: metric,
                group_by: group_by,
                reference: false 
            }
            group_param = jQuery.extend({},param, group_hash);
            return group_param;
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