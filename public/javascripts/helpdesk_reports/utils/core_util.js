HelpdeskReports.CoreUtil = HelpdeskReports.CoreUtil || {};
HelpdeskReports.locals = HelpdeskReports.locals || {};

HelpdeskReports.CoreUtil = {
    MULTI_SELECT_SELECTION_LIMIT: 10,
    FILTER_LIMIT: 5,
    FILTER_LIMIT_MSG: I18n.t('helpdesk_reports.filter_error_msg'),
    CONST: {
        base_url    : "/reports/v2/",
        metrics_url : "/fetch_metrics",
        tickets_url : "/fetch_ticket_list",
        configure_export_url : "/configure_export",
        export_url : "/export_tickets",
        email_reports: "/email_reports",
        save_report : "/save_reports_filter",
        delete_report : "/delete_reports_filter",
        update_report : "/update_reports_filter"
    },
    reports_specific_disabled_filter:{
        "customer_report":["agent_id","group_id","company_id"]
    },
    global_disabled_filter: ["status","historic_status"],
    default_available_filter : [ "agent_id","group_id","company_id" ],
    filter_remote : [ "agent_id","tag_id","company_id"],
    filter_remote_url : {
            "agent_id" : "agents",
            "company_id" : "companies",
            "tag_id" : "tags"
    },
    ATTACH_DEFAULT_FILTER : false,
    /* Time-outs for ajax requests in milliseconds, 
    ** set to 1 min for now. Will be handled at backend later on.
    */
    timeouts: {
        main_request: 60000,
        glance_right_pane: 60000,
        ticket_list: 60000,
        custom_field: 60000
    },
    SHORTEN_LIMIT : 9999,
    getFilterDisplayData: function () {
        var _this = this;
        HelpdeskReports.locals.select_hash = [];
        jQuery("#active-report-filters div.ff_item").map(function () {
            var container  = this.getAttribute("container");
            var data_label = this.getAttribute("data-label");
            var condition = this.getAttribute("condition");
            var value = [];

            if (container == "nested_field") {
                value = jQuery(this).children('select').find('option:selected').text();
            } else {
                //select
                if(jQuery.inArray(condition,_this.filter_remote) != -1) {
                    var data = jQuery(this).find(".filter_item").select2('data');
                    if(data != undefined && data.length > 0){
                        data.map(function(val,i){
                            value.push(val.text); 
                        });
                    }
                } else {
                    value = jQuery(this).find('option:selected').map(function () {
                        return jQuery(this).text();
                    }).get();
                }
            }

            if ((data_label !== null) && value && value.length && ((container !== "nested_field") || ((container === "nested_field") && (value !== "...")))) {
                var values = (typeof value == "string") ? value.toString() : value.join(', ');
                HelpdeskReports.locals.select_hash.push({
                    name: data_label,
                    value: values
                });
            }
        });
        _this.setFilterDisplayData();
    },
    setFilterDisplayData: function () {
        //Incase of sprout plan populte the seperate label in header
         if(HelpdeskReports.locals.is_non_sprout_plan){
            var tmpl = JST["helpdesk_reports/templates/filter_data_template"]({ 
                data: HelpdeskReports.locals.select_hash 
            });
            jQuery("#filter_text").html(tmpl);
            trigger_event("report_refreshed",{});
        } else{
            jQuery(".date-value").html(jQuery("#sprout-datepicker").val());
        }

    },
    setFilterData: function () {
        var _this = this;
        var locals = HelpdeskReports.locals;
        locals.query_hash = [];
        locals.local_hash = [];
        
        jQuery("#active-report-filters div.ff_item").map(function () {
            var condition = this.getAttribute("condition");
            var container = this.getAttribute("container");
            var operator  = this.getAttribute("operator");
            var value = [];
            var isAjaxSourceSelect = false;

            //Store the search results in localStorage, otherwise cant populate the filter on page refresh
            searchData = [];


            if(jQuery.inArray(condition,_this.filter_remote) != -1){
                isAjaxSourceSelect = true;
            }

            if (container == "nested_field") {
                value = (jQuery(this).children('select').val() === null ? "" : jQuery(this).children('select').val());
            } else if (container == "multi_select" || container == "select") {

                if(isAjaxSourceSelect){
                    value = jQuery(this).find(".filter_item").select2('val');
                    searchData = jQuery(this).find(".filter_item").select2('data');
                }else{
                    value = jQuery(this).find('option:selected').map(function () {
                        return this.value;
                    }).get();
                }
            }

            if (value.length) {
                locals.query_hash.push({
                    condition: condition,
                    operator: operator,
                    value: value.toString()
                });
                //local_hash is filters stored in localStorage for populating on load.
                var hash = _this.getLocalHash(condition, container, operator, value,searchData);
                locals.local_hash.push(hash);
            } else {
                //Removing fields with no values in filters by triggering click.(only for non default fields)
                if(HelpdeskReports.CoreUtil.default_available_filter.indexOf(condition) < 0){
                    var active = jQuery('#div_ff_' + condition);
                    if (active.attr('data-type') && active.attr('data-type') === "filter-field") {
                        _this.actions.removeField(active);
                    }    
                }
                
            }
        });
        
    },
    afterFilterValidation: function () {
        var _this  = this;
        var locals = HelpdeskReports.locals;
        
        if(locals.params != undefined) {
            jQuery.each(locals.params, function (index) {
                locals.params[index]['filter'] = locals.query_hash;
            });    
        }
        // TODO: Consider mode this to a cache util.
        // Cache.get(key) / Cache.set(key, data)
        if (typeof (Storage) !== "undefined") {
            //Storing filters in localstorage
            window.localStorage.setItem('reports-filters', locals.local_hash.toJSON());
            //Storing the index of visited report to retain it.
            /*
            var current_selected_index = parseInt(jQuery(".reports-menu li.active a").attr('data-index'));
            window.localStorage.setItem(HelpdeskReports.locals.report_type,current_selected_index); */
        }

        _this.getFilterDisplayData();
        _this.dateChanged();

        if (locals.report_type == 'glance') {
            _this.glanceGroupByFieldsInit();
        }
    },
    getLocalHash: function (condition, container, operator, value,searchData) {
        var locals =  HelpdeskReports.locals;
        var hash = {};
        if (container === 'nested_field' && locals.custom_field_hash.hasOwnProperty(condition)) {
            var nested_values = [];
            for (i = 0; i < locals.custom_field_hash[condition].length; i++) {
                var values = jQuery('#div_ff_' + locals.custom_field_hash[condition][i]).find('select').val();
                nested_values.push(values);
            }
            hash = {
                condition: condition,
                operator: operator,
                value: nested_values
            };
        } else if (container !== 'nested_field') {
            hash = {
                condition: condition,
                operator: operator,
                value: value.toString()
            };
        }

        if(searchData != undefined && searchData.length > 0){
            hash.source = searchData;
        }
        return hash;
    },
    /*TODO: Need to simplify following methods.
      GlanceReport -  groupby field methods start */
    glanceGroupByFieldsInit: function () {
        var locals = HelpdeskReports.locals;
        if (!jQuery.isEmptyObject(locals.custom_field_hash)) {
            this.getCustomFieldsInFilters();
        } else {
            this.GroupByNonCustomFieldAcnt();
        }
    },
    getCustomFieldsInFilters: function () {
        var custom_fields = jQuery('div[type="custom"]').map(function(){ 
            if(jQuery(this).children('select').val().length){
                return jQuery(this).attr('condition');
            }
        }).get();
        this.groupByFieldsForGlance(custom_fields);
    },
    groupByFieldsForGlance: function (custom_fields) {
        var locals = HelpdeskReports.locals;
        var custom_field_keys = _.keys(locals.custom_field_hash);
        var difference = _.difference(custom_field_keys, custom_fields);
        var group_by = []; 

        if (custom_fields.length) {

            for(i=0; i < custom_fields.length; i++){
                var flag = locals.custom_field_hash.hasOwnProperty(custom_fields[i]);
                var container = locals.report_field_hash[custom_fields[i]].container;
                if(flag && container == 'nested_field'){
                    var present = locals.custom_field_hash[custom_fields[i]];
                    for(j=0; j < present.length; j++){ 
                        var val = jQuery('#div_ff_' + present[j]).children('select').val();
                        if(val === null || val === "" || (j == present.length -1)){
                            group_by.push(present[j]);
                            break;
                        }
                    }
                }else if(flag && container == 'multi_select'){
                    group_by.push(custom_fields[i]);
                }
            }

            if (group_by.length) {
                group_by = group_by.concat(difference);
            } else {
                group_by = difference;
            }

        } else {
            group_by = custom_field_keys;
        }
        locals.custom_fields_group_by = group_by;
        this.setCurrentGroupBy();
    },
    setCurrentGroupBy: function () {
        var locals = HelpdeskReports.locals;
        
        var current_group = this.setDefaultGroupByOptions(HelpdeskReports.locals.active_metric);
        
        if (locals.custom_fields_group_by.length) {
            if(HelpdeskReports.locals.report_type == 'glance' && localStorage.getItem('glance') != '-1'){
                var rf = _.find(HelpdeskReports.locals.report_filter_data, function(rfd){ return rfd.report_filter.id == parseInt(localStorage.getItem('glance'))})
                var active_cf;
                if(rf != null && (active_cf = rf.report_filter.data_hash.active_custom_field)){
                    current_group.push(active_cf);
                    HelpdeskReports.locals.active_custom_field = active_cf;
                }
                else
                    current_group.push(locals.custom_fields_group_by[0]);
            }
            else{
                current_group.push(locals.custom_fields_group_by[0]);
            }
        }
        locals.current_group_by = current_group;
    },
    GroupByNonCustomFieldAcnt: function () {
        var locals = HelpdeskReports.locals;
        locals.custom_fields_group_by = [];
        locals.current_group_by = this.setDefaultGroupByOptions(HelpdeskReports.locals.active_metric);
    },
    setDefaultGroupByOptions: function (active_metric) {
        var groupby = [];
        var constants = jQuery.extend({}, HelpdeskReports.Constants.Glance);

        if (constants.status_metrics.indexOf(active_metric) > -1) {
            groupby = constants.group_by_with_status.slice();
            if(active_metric == "UNRESOLVED_TICKETS")
            {   
                var account_end_date = HelpdeskReports.locals.endDate;
                var date_range       = HelpdeskReports.locals.date_range.split(' - ')
                var end_date         = date_range.length == 1 ? date_range[0] : date_range[1]
                if((Date.parse(account_end_date) - Date.parse(end_date)) != 0){
                    groupby.push("historic_status")
                }
            }
        } else {
            groupby = constants.group_by_without_status.slice();
        }
        //Adding extra options - Product if product is present
        if(!jQuery.isEmptyObject(HelpdeskReports.locals.report_options_hash['product_id'])){
            groupby.push(constants.group_by_extra_options);
        }
        return groupby;
    },
    // GlanceReport -  groupby fields ends
    dateChanged: function () {
        var locals    = HelpdeskReports.locals;
        var date      = jQuery('#date_range').val();
        if(HelpdeskReports.locals.is_non_sprout_plan){
            date  = jQuery('#date_range').val();
        } else {
            date = jQuery('#sprout-datepicker').val();
        }
        //var preRanges = locals.presetRangesSelected;
        locals.date_range = date;
        if(locals.params != undefined) {
            jQuery.each(locals.params, function (index) {
                locals.params[index]['date_range'] = date;
            });
        }
            
       /* 
       if (typeof (Storage) !== "undefined") {
            switch(preRanges){
                case true:
                    window.localStorage.setItem('reports-date-diff',this.dateRangeDiff().toJSON());
                    window.localStorage.setItem('reports-presetRangesSelected',true);
                    window.localStorage.removeItem('reports-date-range');
                    break;
                case false:
                    window.localStorage.setItem('reports-date-range',locals.date_range.toJSON());    
                    window.localStorage.setItem('reports-presetRangesSelected',false);
                    window.localStorage.removeItem('reports-date-diff');
                    break;
            }
        }
        HelpdeskReports.locals.presetRangesSelected = false;*/

    },
    refreshReports: function () {
        var _this = this;
        var locals = HelpdeskReports.locals;

        _this.setFilterData();

        if ( locals.query_hash.length <= _this.FILTER_LIMIT ) {
            
            _this.flushErrorMsg();
            _this.afterFilterValidation();
            
            return true;

        } else {
            
            _this.showErrorMsg();

            if(!jQuery("#report-filters").is(":visible")){
                _this.actions.openFilterMenu();
            }
            
            return false;

        }

    },
    showErrorMsg: function () {
        var msg = this.FILTER_LIMIT_MSG;
        jQuery('#filter_validation_errors .error-msg').text(msg);
    },
    flushErrorMsg: function () {
        jQuery('#filter_validation_errors .error-msg').text('');
    },
    makeAjaxRequest: function (args) {
        args.url = args.url;
        args.type = args.type ? args.type : "POST";
        args.dataType = args.dataType ? args.dataType : "json";
        args.data = args.data;
        args.success = args.success ? args.success : function () {};
        args.error = args.error ? args.error : function () {};
        var _request = jQuery.ajax(args);
    },
    bindEvents: function () {
        var _this = this;
        jQuery('#reports_wrapper').on('click.helpdesk_reports', '[data-action="add-filter"]', function () {
            _this.actions.toggleFilterListMenu();
        });
        jQuery('#reports_wrapper').on('click.helpdesk_reports', '[data-action="pop-field"]', function () {
            var selected = jQuery(this).data('menu');
            _this.constructReportField(selected);
        });
        jQuery('#reports_wrapper').on('click.helpdesk_reports', '[data-action="remove-field"]', function () {
            _this.actions.removeField(this);
        });
        jQuery('#reports_wrapper').on('click.helpdesk_reports', '[data-action="pop-report-type-menu"]', function (event) {
            event.stopImmediatePropagation();
            _this.actions.toggleReportTypeMenu();
        });
        jQuery('#reports_wrapper').on('click.helpdesk_reports', function () {
            _this.actions.hideReportTypeMenu();
        });
        jQuery('#reports_wrapper').on('click.helpdesk_reports', '[data-action="open-filter-menu"]', function () {
            //Each Report Util will set whether to attach default filters to the active menu on init function
            _this.actions.openFilterMenu();
        });
        jQuery('#reports_wrapper').on('click.helpdesk_reports', '[data-action="close-filter-menu"]', function () {
            _this.actions.closeFilterMenu();
        });
        jQuery(document).on('click.helpdesk_reports', '[data-action="hide-ticket-list"]', function () {
            _this.actions.hideTicketList();
        });
        jQuery(document).keyup(function(e) {
             if (e.keyCode == 27) { 
                // escape key maps to keycode `27`
                _this.actions.hideTicketList();
                _this.actions.hideNestedFieldDrillDown();
            }
        }); 
        jQuery(document).on('mousemove.helpdesk_reports', '.ticket-list-wrapper,#view_more_wrapper', function(event) {
            event.preventDefault();
            jQuery('body').addClass('preventscroll');
        });
        jQuery(document).on('mouseleave.helpdesk_reports', '.ticket-list-wrapper,#view_more_wrapper', function(event) {
            event.preventDefault();
            jQuery('body').removeClass('preventscroll');
        });
        jQuery('#reports_wrapper').on('keypress.helpdesk_reports keyup.helpdesk_reports keydown.helpdesk_reports', "#date_range", function (ev) {
            _this.actions.disableKeyPress(ev);
        });
        jQuery(document).on("presetRangesSelected", function(event,data) {
            HelpdeskReports.locals.presetRangesSelected = data.status;
            HelpdeskReports.locals.presetRangesPeriod = data.period;
        });
        jQuery('#reports_wrapper').on('mousemove.helpdesk_reports', '.report-filters-container', function(event) {
            event.preventDefault();
            if(jQuery(this).hasScrollBar()){
                jQuery('body').addClass('preventscroll');
            }else{  
                jQuery('body').removeClass('preventscroll');
            }
        });
        jQuery('#reports_wrapper').on('mouseleave.helpdesk_reports', '.report-filters-container', function(event) {
            event.preventDefault();
            jQuery('body').removeClass('preventscroll');
        });
        jQuery('.ticket-list-wrapper').on('click.helpdesk_reports', "[data-action='toggle-ticketlist']", function () {
                //Toggle sla Links & Labels
                 var el = this;
                 var link = jQuery(el).attr('data-link');
                 var value_of_metric = jQuery(el).data('metric-value');
                 jQuery(el).addClass('active');
                 if( link == 'violated'){
                    jQuery('[data-link="compliant"]').removeClass('active');
                    _this.actions.toggleTicketList(true,value_of_metric);
                 } else{
                    jQuery('[data-link="violated"]').removeClass('active');
                    _this.actions.toggleTicketList(false,value_of_metric);
                 }
        });
        /* Export Section */
        jQuery(".export_title a, #export_cancel").on('click',function(){   
                _this.toggleExportSection();
        });
         
        jQuery('#reports_wrapper').on('click.helpdesk_reports', '#generate_pdf_async', function(){
            _this.generatePdfAsync();
            var timeOutSeconds = 5
            var btn = jQuery(this);
            btn.prop('disabled', true);
            setTimeout(function(){
                btn.prop('disabled', false);
            }, timeOutSeconds*1000);
            trigger_event("analytics.export_pdf",{});
        });
        
        _this.addIndexToFields();
        _this.generateReportFiltersMenu();
        _this.customFieldHash();
        _this.scrollTop();
        _this.actions.setTicketListFlag();
        _this.adjustFilterButton();
    },
    actions : {
        closeFilterMenu: function () {
            if(jQuery('#inner').hasClass('openedit')){
                jQuery('#inner').removeClass('openedit');
                setTimeout(function(){
                   jQuery("#report-filters").hide();
                }, 100);
            }
            if (jQuery("#report_fields_list").is(':visible')) {
                jQuery("#report_fields_list").hide();
            }
        },
        openFilterMenu: function () {
            jQuery("#report-filters").show();
            jQuery('#inner').addClass('openedit');
            this.hideTicketList();
            this.hideViewMore();
            this.hideNestedFieldDrillDown();
        },
        showTicketList: function (title,value) {
            //Hide the drill down
            this.hideNestedFieldDrillDown();
            //Construct Title
            var base_title = HelpdeskReports.locals.base_task_list_title;
            //Refresh the export section for every ticket list.
            this.flushExportSection();
            jQuery(".list-title .metric_title").empty().html(title);
            jQuery(".list-title .metric_value").empty().html(value);
            jQuery("#ticket_list").html("").addClass('sloading loading-small');
            jQuery('#ticket_list_wrapper').addClass('active');
        },
        hideTicketList: function () {
            if(jQuery('#ticket_list_wrapper').hasClass('active')) {
                jQuery('#ticket_list_wrapper').removeClass('active');
                //Always hide the export section & based on availability of tickets unhide
                jQuery(".export_title").addClass('hide');
                //Always hide the sla tabs & based on active metric it will be unhidden
                jQuery(".sla-toggle-tab").addClass('hide');
            }
        },
        hideViewMore: function() {
            if(jQuery('#view_more_wrapper').hasClass('show-all-metrics')) {
                jQuery('#view_more_wrapper').removeClass('show-all-metrics');
            }
        },
        hideNestedFieldDrillDown : function(){
            if(jQuery('#custom_field_wrapper').hasClass('show-drill-down')) {
                jQuery('#custom_field_wrapper').removeClass('show-drill-down');
                //Remove the breadcrumb
                HelpdeskReports.locals.breadcrumb = [];
                HelpdeskReports.locals.drill_down_hash = [];
                //Remove any nested field filter conditions added previously
                for(i = HelpdeskReports.locals.query_hash.length ;i>0 ;i--){
                    var index = HelpdeskReports.locals.query_hash.length - i; 
                    var filter = HelpdeskReports.locals.query_hash[index];
                    if(filter.nested_field_filter != undefined && filter.nested_field_filter){
                        HelpdeskReports.locals.drill_down_hash.push(HelpdeskReports.locals.query_hash.splice(index,1)[0]);
                    }
                }
            }
        },
        showViewMore: function () {
            jQuery('#view_more_wrapper').addClass('show-all-metrics');
        },
        showNestedFieldDrillDown : function(){
            this.hideTicketList();
            jQuery('#custom_field_wrapper').addClass('show-drill-down');
        },
        toggleReportTypeMenu: function () {
            var menu = jQuery('#reports_type_menu');
            if (!menu.is(':visible')) {
                menu.removeClass('hide');
            } else {
                menu.addClass('hide');
            }
        },
        hideReportTypeMenu: function () {
            var menu = jQuery('#reports_type_menu');
            if (menu.is(':visible')) {
                menu.addClass('hide');
            }
        },
        toggleFilterListMenu: function () {
            var _this = HelpdeskReports.CoreUtil;
            var menu = "#report_fields_list";
            if (!jQuery(menu).is(':visible') && jQuery(menu + ' li').length !== 0) {
                jQuery(menu).show();
            } else {
                jQuery(menu).hide();
            }
        },
        removeField: function (active) {
            var _this = HelpdeskReports.CoreUtil;
            var field = jQuery(active).closest("[data-type='filter-field']");
            _this.removeReportField(field.attr('condition'), field.attr('data-label'));
        },
        disableKeyPress: function (ev) {
            ev.preventDefault();
            return false;
        },
        setTicketListFlag: function () {
            HelpdeskReports.locals.ticket_list_flag = false;
        },
        flushExportSection : function() {

             jQuery(".fields").removeAttr("style"); //Inline Style added by JQuery SlideToogle
             jQuery(".export_title .title").addClass('hide');
             jQuery(".export_title .link").removeClass('hide');

             //Reset the Export Button
             jQuery("#export_submit").removeAttr('disabled').removeClass('disabled').html("Export");
             jQuery(".success_message").removeAttr('style').addClass('hide');
             jQuery(".error_message").removeAttr('style').addClass('hide');
        },
        constructSlaTabs : function(metric_value){
            //Unhide the SLA Toggle in Ticket list
            var _this = HelpdeskReports.CoreUtil;
            jQuery(".sla-toggle-tab").removeClass('hide');
            var report_type = HelpdeskReports.locals.report_type;

            if(report_type == "customer_report"){
                //populate the tab title's
                var violated_title =  _this.addsuffix(metric_value) + " " + I18n.t('helpdesk_reports.violated_tickets');
                jQuery(".sla-toggle-tab .link1 .toggle").html(violated_title);
                jQuery(".sla-toggle-tab .link1 .toggle").attr('data-link','violated');

                //populate the tab title's
                var complaint_val = 100 - parseInt(metric_value);
                var complaint_title =  _this.addsuffix(complaint_val) + " " + I18n.t('helpdesk_reports.compliant_tickets');
                jQuery(".sla-toggle-tab .link2 .toggle").html(complaint_title);
                jQuery(".sla-toggle-tab .link2 .toggle").attr('data-link','compliant');
                
                //add value attribute to links
                jQuery(".sla-toggle-tab .link1 .toggle").data('metric-value',metric_value);
                jQuery(".sla-toggle-tab .link2 .toggle").data('metric-value',complaint_val);
            } 

            if(report_type == "agent_summary" || report_type == "group_summary"){
                //populate the tab title's
                var compliant_title =  _this.addsuffix(metric_value) + " " + I18n.t('helpdesk_reports.compliant_tickets');
                jQuery(".sla-toggle-tab .link1 .toggle").html(compliant_title);
                jQuery(".sla-toggle-tab .link1 .toggle").attr('data-link','compliant');

                //populate the tab title's
                var violated_val = 100 - parseInt(metric_value);
                var violated_title =  _this.addsuffix(violated_val) + " " + I18n.t('helpdesk_reports.violated_tickets');
                jQuery(".sla-toggle-tab .link2 .toggle").html(violated_title);
                jQuery(".sla-toggle-tab .link2 .toggle").attr('data-link','violated');
                
                //add value attribute to links
                jQuery(".sla-toggle-tab .link1 .toggle").data('metric-value',metric_value);
                jQuery(".sla-toggle-tab .link2 .toggle").data('metric-value',violated_val);
            }
            
        },
        resetSlaLinks : function(){
            jQuery('.link1 .toggle').addClass('active');
            jQuery('.link2 .toggle').removeClass('active');
        },
        toggleTicketList : function(value,metric_value){
             var _this = HelpdeskReports.CoreUtil;
             var list_params = HelpdeskReports.locals.list_params;
             //Update supplement condition
             var supplement_condition = list_params[0].list_conditions[1];
             if(supplement_condition != undefined ){
                supplement_condition.value = value; 
             }
             jQuery("#ticket_list").html("").addClass('sloading loading-small');
             //Don't make service call if metric value is zero.There will be no data eventually.
             if(metric_value && metric_value != 0){
                _this.fetchTickets(list_params);   
             }else{
                var empty = [];
                //Hide the export button for empty data
                 jQuery(".export_title").addClass('hide');
                _this.appendTicketList(empty);  
             }
             
        }
    },
    addIndexToFields: function () {
        var hash = HelpdeskReports.locals.report_field_hash;
        var index = 0;
        for (var key in hash) {
            hash[key].position = index;
            index++;
        }
    },
    customFieldHash: function () {
        var locals = HelpdeskReports.locals;
        var hash = locals.report_field_hash;
        locals.custom_field_hash = {};
        for (var key in hash) {
            if (hash[key]['field_type'] === 'custom' && hash[key]['container'] === 'nested_field') {
                var fields = [];
                fields.push(hash[key]['condition']);
                for (i = 0; i < hash[key]['nested_fields'].length; i++) {
                    fields.push(hash[key]['nested_fields'][i]['condition']);
                }
                locals.custom_field_hash[key] = fields;
            } else if (hash[key]['field_type'] === 'custom' && hash[key]['container'] === 'multi_select') {
                locals.custom_field_hash[key] = [];
            }
        }
    },
    generateReportFiltersMenu: function () {
        var _this = this;
        var locals = HelpdeskReports.locals;
        var menu_tmpl = JST["helpdesk_reports/templates/filter_menu"]({
            data: locals.report_field_hash
        });
        jQuery("#report_fields_list ul").html(menu_tmpl);
    },
    constructReportField: function (field, val) {
        var _this = this;
        var _this_hash = HelpdeskReports.locals.report_field_hash;
        var val = val || "";
        var present = jQuery('#active-report-filters').find(jQuery('[condition=' + field + ']'));
        if (field in _this_hash && !present.length) {
            var field_hash = _this_hash[field];
            field_hash.active = true;
            if (field_hash.container && field_hash.container === 'nested_field') {
                _this.constructNestedField(field_hash, val);
            } else {
                _this.constructMultiSelect(field_hash, val);
            }
            _this.removeFieldFromMenu(field);
        }
        _this.hideFilterMenu();
    },
    constructNestedField: function (field_hash, val) {
        var _this = this;
        var tmpl = JST["helpdesk_reports/templates/nested_field_tmpl"](field_hash);
        jQuery(tmpl).appendTo('#active-report-filters');
        jQuery('#' + field_hash.field_id + '_category').nested_select_tag({
            initValues: _this.nestedFieldInitValues(val),
            default_option: "<option value=''>...</option>",
            data_tree: field_hash.options,
            subcategory_id: field_hash.field_id + '_sub_category',
            item_id: field_hash.field_id + '_item_sub_category'
        });
    },
    constructMultiSelect: function (field_hash, val) {
        var _this = this;
        var tmpl = JST["helpdesk_reports/templates/multiselect_tmpl"](field_hash);
        jQuery(tmpl).appendTo('#active-report-filters');

        var config = {
            maximumSelectionSize: _this.MULTI_SELECT_SELECTION_LIMIT
        };
        if(jQuery.inArray(field_hash.condition,_this.filter_remote) != -1){
            config = _this.getRemoteFilterConfig(field_hash.condition,false);
        }
        jQuery("#" + field_hash.condition).select2(config);
        if (val.length) {
            jQuery("#" + field_hash.condition).select2('val', val.split(','));
        }
    },
    getRemoteFilterConfig : function(condition,initFromSavedReportData,initData){
         var _this = this;
         var include_none = true;
         var noneVal = "-None-" ;
         var none_value = -1;

         var config = {
            maximumSelectionSize: _this.MULTI_SELECT_SELECTION_LIMIT
        };
         config.ajax = {
            url: "/search/autocomplete/" + _this.filter_remote_url[condition],
            dataType: 'json',
            delay: 250,
            data: function (term, page) {
                searchText = term;
                return {
                    q: term, // search term
                };
            },
            results: function (data, params) {
                      var results = [];
                      jQuery.each(data.results, function(index, item){
                        if(condition == "agent_id") {
                            results.push({
                              id: item.user_id,
                              text: item.value
                            });
                        } else {
                            results.push({
                              id: item.id,
                              text: item.value
                            });    
                        }
                      });
                      if(condition == "agent_id") {
                            if(include_none && noneVal.toLowerCase().indexOf(searchText.toLowerCase()) > -1){
                                results.push({
                                    id: -1, 
                                    text: noneVal
                                });
                            }
                     }
                      return {
                        results: results 
                      };
            },
            cache: true
          };
          config.multiple = true ;
          config.minimumInputLength = 2 ;
          config.initSelection = function (element, callback) {
                if(initFromSavedReportData){
                    callback(initData);
                } else {
                    if (typeof (Storage) !== "undefined" && localStorage.getItem('reports-filters') !== null) {
                        var filter = JSON.parse(localStorage.getItem('reports-filters'));
                        jQuery.each(filter, function(i,obj){
                            if(obj.condition == condition){
                                if(obj.source != undefined) {
                                    callback(obj.source);    
                                }
                                return false;
                            }
                        });
                    }   
                }
            };
        return config;
    },
    nestedFieldInitValues: function (val) {
        var init = {
            "category_val"    : val.length && val[0] !== null ? val[0] : null,
            "subcategory_val" : val.length && val[1] !== null ? val[1] : null,
            "item_val"        : val.length && val[2] !== null ? val[2] : null
        }

        return init;
    },
    hideFilterMenu: function () {
        if (!jQuery("[data-action='pop-field']").length) {
            jQuery("[data-action='add-filter']").hide();
            jQuery("#report_fields_list").hide();
        }
    },
    removeFieldFromMenu: function (field) {
        var _this = this;
        jQuery('li[data-menu="' + field + '"]').remove();
    },
    removeReportField: function (condition, dataLabel) {
        var _this = this;
        if (condition.length && dataLabel.length && !jQuery('[data-menu="' + condition + '"]').length) {
            jQuery('#div_ff_' + condition).remove();
            var field = '<li data-position="' + HelpdeskReports.locals.report_field_hash[condition].position + '" data-action="pop-field" data-menu="' + condition + '">' + escapeHtml(dataLabel) + '</li>';
            jQuery("#report_fields_list" + " ul").append(field);
            HelpdeskReports.locals.report_field_hash[condition]["active"] = false;
        }
        _this.sortFilterMenu();
        _this.checkFilterOptions();
    },
    sortFilterMenu: function () {
        var list = jQuery("[data-action='pop-field']");
        var listItems = list.sort(function (a, b) {
            return (jQuery(b).data('position')) < (jQuery(a).data('position')) ? 1 : -1;
        }).appendTo('#report_fields_list ul');
    },
    checkFilterOptions: function () {
        //Show filter menu when all fields not selected
        if (jQuery("[data-action='pop-field']").length && !jQuery("[data-action='add-filter']").is(':visible')) {
            jQuery("[data-action='add-filter']").show();
        }
    },
    setReportFilters: function () {
        var _this = this;
        var filter = [];
        var dateDiff = 29;
        var daterange;

        if (typeof (Storage) !== "undefined" && localStorage.getItem('reports-filters') !== null) {
            filter = JSON.parse(localStorage.getItem('reports-filters'));
        }
        /* Code to populate the daterange from localstorage
        if (typeof (Storage) !== "undefined" && localStorage.getItem('reports-presetRangesSelected') !== null) {
            if(JSON.parse(localStorage.getItem('reports-presetRangesSelected'))){
                if (typeof (Storage) !== "undefined" && localStorage.getItem('reports-date-diff') !== null) {
                    dateDiff  = JSON.parse(localStorage.getItem('reports-date-diff'));
                    daterange = this.convertDateDiffToDate(dateDiff);
                }
            }else{
                if (typeof (Storage) !== "undefined" && localStorage.getItem('reports-date-range') !== null) {
                    daterange = JSON.parse(localStorage.getItem('reports-date-range'));
                }    
            }
        }else{
            daterange = this.convertDateDiffToDate(dateDiff);   
        }*/
        daterange = this.convertDateDiffToDate(dateDiff); 

        //Each report will decide, whether to add default filters or not to active menu ( agent,group,customer)
        if(_this.ATTACH_DEFAULT_FILTER) {

            _this.ATTACH_DEFAULT_FILTER = false;

            //Add default filter fields to list
            var defaultFilters = HelpdeskReports.CoreUtil.default_available_filter;
            _.each(defaultFilters,function(el,idx){
                //check if the default filter was used,
                //if so populate the report field with value else popoulate field with empty
                var filter_contains_default = false;
                var filter_value = "";
                if (filter.length) {
                    jQuery(filter).each(function (index, hash) {
                        if (HelpdeskReports.locals.report_field_hash.hasOwnProperty(hash.condition) && _this.global_disabled_filter.indexOf(hash.condition) < 0 && (_this.reports_specific_disabled_filter[HelpdeskReports.locals.report_type] || []).indexOf(hash.condition) < 0) {
                            if(el == hash.condition){
                               //Filter has been applied to default field
                               filter_contains_default  = true;
                               filter_value = hash.value;
                               return false; //break the loop
                            }
                            
                        }
                    });
                }
                if(filter_contains_default){
                    _this.constructReportField(el);//,filter_value);
                } else {
                     _this.constructReportField(el);
                }
            });    
        }
        //Duplicates will not be inserted, Condition checking in constructReportField function
        if (filter.length) {
            jQuery(filter).each(function (index, hash) {
                if (HelpdeskReports.locals.report_field_hash.hasOwnProperty(hash.condition) && _this.global_disabled_filter.indexOf(hash.condition) < 0 && (_this.reports_specific_disabled_filter[HelpdeskReports.locals.report_type] || []).indexOf(hash.condition) < 0) {
                    _this.constructReportField(hash.condition)//,hash.value);
                }
            });
        }
        
        jQuery('#date_range').val(daterange);
        jQuery('#sprout-datepicker').val(daterange);
        var date = jQuery('#date_range').val();
        _this.constructDateRangePicker();

        HelpdeskReports.SavedReportUtil.init(-1);
        return date;
    },
    convertDateDiffToDate: function (dateDiff) {
        var dateFormat = getDateFormat('mediumDate').toUpperCase();   
        var date_lag   = HelpdeskReports.locals.date_lag;
        moment.lang('en');
        var endDate    = moment.tz(new Date(),HelpdeskReports.locals.account_time_zone).subtract(date_lag,"days").format(dateFormat);
        var startDate  = moment.tz(new Date(),HelpdeskReports.locals.account_time_zone).subtract((dateDiff + date_lag),"days").format(dateFormat);
        if(dateDiff == 0 ){
            finaldate = endDate;
        }else if(dateDiff == 1){
            finaldate = startDate;
        }else{
            finaldate = startDate + " - " + endDate;    
        }
        return finaldate;
    },   
    convertPresetRangesToDate : function(period,diff) {
        
        var dateFormat = getDateFormat('mediumDate').toUpperCase();   
        var date_lag   = HelpdeskReports.locals.date_lag;
        var date_const = Helpkit.DateRange;
        moment.lang('en');
        var date_ranges = this.getDateRangeDefinition(dateFormat,date_lag);

        //For exisiting saved reports
        if(period == undefined) {
            return this.convertDateDiffToDate(diff);
        }
        
        if(period == date_const.TODAY){
            return date_ranges['endDate'];
        } else if(period == date_const.YESTERDAY) {
            return date_ranges['1'];
        } else if(period == date_const.LAST_7){
            return date_ranges[7] + " - " + date_ranges['endDate'];
        } else if(period == date_const.LAST_30) {
            return date_ranges[30] + " - " + date_ranges['endDate'];
        } else if(period == date_const.LAST_90) {
            return date_ranges[90] + " - " + date_ranges['endDate'];
        } else if(period == date_const.THIS_WEEK) {
            var end_date        = date_ranges['endDate'];
            var this_week_start = date_ranges['this_week_start'];
            var this_week_end   = Date.parse(end_date) <= Date.parse(this_week_start) ? this_week_start : end_date;                    
            return this_week_start + " - " + this_week_end;
        } else if(period == date_const.PREVIOUS_WEEK) {
            return date_ranges['previous_week_start'] + " - " + date_ranges['previous_week_end'];
        } else if(period == date_const.THIS_MONTH) {
            var end_date         = date_ranges['endDate'];
            var this_month_start = date_ranges['this_month_start'];
            var this_month_end   = Date.parse(end_date) <= Date.parse(this_month_start) ? this_month_start : end_date;                    
            return this_month_start + " - " + this_month_end;
        } else if(period == date_const.PREVIOUS_MONTH) {
            return date_ranges['previous_month_start'] + " - " + date_ranges['previous_month_end'];
        } else if(period == date_const.LAST_3_MONTHS) {
            var end_date      = date_ranges['endDate'];
            var three_month_start = date_ranges['last_3_months'];
            var three_month_end   = Date.parse(end_date) <= Date.parse(three_month_start) ? three_month_start : end_date;                    
            return three_month_start + " - " + three_month_end;
        } else if(period == date_const.LAST_6_MONTHS) {
            var end_date      = date_ranges['endDate'];
            var six_month_start = date_ranges['last_6_months'];
            var six_month_end   = Date.parse(end_date) <= Date.parse(six_month_start) ? six_month_start : end_date;                    
            return six_month_start + " - " + six_month_end;
        } else if(period == date_const.THIS_YEAR) {
            var end_date        = date_ranges['endDate'];
            var this_year_start = date_ranges['this_year_start'];
            var this_year_end   = Date.parse(end_date) <= Date.parse(this_year_start) ? this_year_start : end_date;                    
            return this_year_start + " - " + this_year_end;
        } 
    },
    calculateDateLag: function () {
        var date_lag = HelpdeskReports.locals.date_lag;
        var dateFormat = getDateFormat('mediumDate').toUpperCase();   
        date = {};
        if (date_lag === undefined) {
            date_lag = 0;   
        }
        moment.lang('en');
        date = this.getDateRangeDefinition(dateFormat,date_lag);
        HelpdeskReports.locals.endDate = date.endDate;

        return date;
    },
    constructDateRangePicker: function () {

        var date = this.calculateDateLag();
            if(HelpdeskReports.locals.is_non_sprout_plan){
                var presetRanges = [{
                    text: I18n.t('helpdesk_reports.this_week'),
                    dateStart: date.this_week_start,
                    dateEnd: Date.parse(date.endDate) <= Date.parse(date.this_week_start) ? date.this_week_start : date.endDate,
                    period : "this_week"
                },{
                    text: I18n.t('helpdesk_reports.previous_week'),
                    dateStart: date.previous_week_start,
                    dateEnd: date.previous_week_end,
                    period : "previous_week"
                },{
                    text: I18n.t('helpdesk_reports.last_num_days',{ num: 7 }),
                    dateStart: date[7],
                    dateEnd: date.endDate,
                    period : "last_7"
                },{
                    text: I18n.t('helpdesk_reports.this_month'),
                    dateStart: date.this_month_start,
                    dateEnd: Date.parse(date.endDate) <= Date.parse(date.this_month_start) ? date.this_month_start : date.endDate,
                    period : "this_month"
                },{
                    text: I18n.t('helpdesk_reports.previous_month'),
                    dateStart: date.previous_month_start,
                    dateEnd: date.previous_month_end,
                    period : "previous_month"
                },{
                    text: I18n.t('helpdesk_reports.last_num_days',{ num: 30 }),
                    dateStart: date[30],
                    dateEnd: date.endDate,
                    period : "last_30"
                },{
                    text: I18n.t('helpdesk_reports.last_num_months',{ num : '3'}),
                    dateStart: date.last_3_months,
                    dateEnd: Date.parse(date.endDate) <= Date.parse(date.last_3_months) ? date.last_3_months : date.endDate ,
                    period : "last_3_months"
                },{
                    text: I18n.t('helpdesk_reports.last_num_days',{ num: 90 }),
                    dateStart: date[90],
                    dateEnd: date.endDate,
                    period : "last_90"
                },{
                    text: I18n.t('helpdesk_reports.last_num_months',{ num : '6'}),
                    dateStart: date.last_6_months,
                    dateEnd: Date.parse(date.endDate) <= Date.parse(date.last_6_months) ? date.last_6_months : date.endDate,
                    period : "last_6_months"
                },{
                    text: I18n.t('helpdesk_reports.this_year'),
                    dateStart: date.this_year_start, 
                    dateEnd: Date.parse(date.endDate) <= Date.parse(date.this_year_start) ? date.this_year_start : date.endDate,
                    period : "this_year"
                }];
            }else{
                var presetRanges = [{
                    text: I18n.t('helpdesk_reports.last_num_days',{ num: 7 }),
                    dateStart: date[7],
                    dateEnd: date.endDate
                }, {
                    text: I18n.t('helpdesk_reports.last_num_days',{ num: 30 }),
                    dateStart: date[30],
                    dateEnd: date.endDate
                }, {
                    text: I18n.t('helpdesk_reports.last_num_days',{ num: 90 }),
                    dateStart: date[90],
                    dateEnd: date.endDate
                }];
            }
            if(HelpdeskReports.locals.date_lag == 0){
                presetRanges.unshift({
                    text: I18n.t('helpdesk_reports.today'),
                    dateStart: date.endDate,
                    dateEnd: date.endDate,
                    period : 'today'
                },{
                    text: I18n.t('helpdesk_reports.yesterday'),
                    dateStart: date[1],
                    dateEnd: date[1],
                    period : 'yesterday'
                });
            }else{
                presetRanges.unshift({
                    text: I18n.t('helpdesk_reports.yesterday'),
                    dateStart: date.endDate,
                    dateEnd: date.endDate,
                    period : 'yesterday'
                });
            }

        var config = {
                earliestDate: Date.parse('01/01/2010'),
                latestDate: Date.parse(date.end_date_with_no_lag),
                presetRanges: presetRanges,
                presets: {
                    dateRange: I18n.t('helpdesk_reports.date_range')
                },
                rangeStartTitle: I18n.t('helpdesk_reports.start_date'),
                rangeEndTitle: I18n.t('helpdesk_reports.end_date'),
                presetRangesCallback: true, 
                dateFormat: getDateFormat('datepicker'),
                closeOnSelect: true,
                rangeDurationMonths : 24,
                limitRangeToConstraints : true
            };

        //Different date pickers for sprout plan & others
        if(HelpdeskReports.locals.is_non_sprout_plan){
            config.onChange = function() {
                trigger_event("filter_changed",{});
            };
            jQuery("#date_range").daterangepicker(config);
        } else{
            //Hide the appliced filter details as there is only date for sprout plan
            jQuery("#filter_text").addClass('hide');
            var previous_value = jQuery('#sprout-datepicker').val();

            config.onClose = function(){
                    //populate the input field with val
                    setTimeout(function(){
                        var selected_value = jQuery(picker).val();
                        if( selected_value != '' && selected_value != previous_value){
                            jQuery("#sprout-datepicker").val(selected_value);
                            previous_value = selected_value;
                            jQuery("[data-action='reports-submit']").trigger('click.helpdesk_reports');
                        }    
                    },100);
                    
            };
            var picker = jQuery("#sprout-datepicker").daterangepicker(config);
        }
    },
    generateCharts: function (params) {
        var _this = this;
        _this.scrollTop();
        if (HelpdeskReports.locals.report_type == 'performance_distribution' && HelpdeskReports.locals.date_range.split("-").length == 1 ){
            params = params.filter(function(param){
                            return param['bucket'] == true;
                     });
            jQuery.each(params,function(idx,param){
                param['query_with_avg'] = true;
            })
        }
        //Append the saved report used param
        jQuery.each(params,function(idx,param){
            param['saved_report_used'] = HelpdeskReports.locals.saved_report_used;
        })
        var opts = {
            url: _this.CONST.base_url + HelpdeskReports.locals.report_type + _this.CONST.metrics_url,
            type: 'POST',
            dataType: 'html',
            contentType: 'application/json',
            data: Browser.stringify(params),
            timeout: _this.timeouts.main_request,
            success: function (data) {
                _this.showWrappers();
                jQuery("#reports_container").html(data);
            },
            error: function (data) {
                _this.showWrappers();
                var text = I18n.t('helpdesk_reports.something_went_wrong_msg');
                _this.populateEmptyChart(["reports_container"], text);
            }
        }
        _this.makeAjaxRequest(opts);
    },
    showWrappers: function () {
        jQuery('#view_more_wrapper').removeClass('hide');
        jQuery('#reports_wrapper').removeClass('hide');
        jQuery('#ticket_list_wrapper').removeClass('hide');
        jQuery('#loading-box').hide();
    },
    fetchTickets: function (params) {
        var _this = this;
        _this.actions.closeFilterMenu();

        var opts = {
            url: _this.CONST.base_url + HelpdeskReports.locals.report_type + _this.CONST.tickets_url,
            type: 'POST',
            dataType: 'json',
            contentType: 'application/json',
            data: Browser.stringify(params),
            timeout: _this.timeouts.ticket_list,
            success: function (data) {
                _this.appendTicketList(data);
                _this.actions.setTicketListFlag();
                //Show Export Section
                if( data && data.length > 0){
                    jQuery(".export_title").removeClass('hide');
                }else{
                    jQuery(".export_title").addClass('hide');
                }
            },
            error: function (data) {
                _this.appendTicketListError();
                _this.actions.setTicketListFlag();
            }
        }
        _this.makeAjaxRequest(opts);
    },
    appendTicketList: function (data) {
        var tmpl = JST["helpdesk_reports/templates/ticketlist_tmpl"]({
            'data': data
        });
        jQuery("#ticket_list").removeClass('sloading loading-small');
        jQuery('#ticket_list').html(tmpl);
    },
    appendTicketListError: function () {
        var _this = this;
        var div = ['ticket_list'];
        var msg = I18n.t('helpdesk_reports.something_went_wrong_msg');
        jQuery("#ticket_list").removeClass('sloading loading-small');
        _this.populateEmptyChart(div, msg);
    },
                     /* Start of Export Code*/
    fetchExportFields : function (data) {
        var _this = this;

        if( data && data.length > 0){
            _this.appendExportFields(data);    
        } else {
            var opts = {
                url: _this.CONST.base_url + HelpdeskReports.locals.report_type + _this.CONST.configure_export_url,
                type: 'GET',
                dataType: 'json',
                contentType: 'application/json',
                timeout: _this.timeouts.ticket_list,
                success: function (data) {
                   HelpdeskReports.locals.export_fields = data;
                   _this.appendExportFields(data);
                },
                error: function (data) {
                    _this.appendExportError();
                }
            }
            _this.makeAjaxRequest(opts);
        }
    },
    appendExportFields : function (data) {
        var _this = this;

        var tmpl = JST["helpdesk_reports/templates/export_fields_tmpl"]({
            'data': data
        });
        jQuery("#ticket_fields").removeClass('sloading loading-small');
        jQuery('#ticket_fields').html(tmpl);
        this.bindExportFieldEvents();
    },
    appendExportError: function () {
        var _this = this;
        var div = ['ticket_fields'];
        var msg = I18n.t('helpdesk_reports.something_went_wrong_msg');
        jQuery("#ticket_fields").removeClass('sloading loading-small');
    },
    exportCSV : function() {
        var _this = this;

        //Data for Ajax request
        var export_options = {};
        export_options.query_hash = HelpdeskReports.locals.list_params[0];
        export_options.date_range = HelpdeskReports.locals.date_range,
        export_options.select_hash = HelpdeskReports.locals.select_hash;
        
        if(parseInt(jQuery(".reports-menu li.active a").attr('data-index')) > -1){
            export_options.filter_name = jQuery(".reports-menu li.active a").attr('data-original-title'); 
        }
        
        //Add the metric title and value to the request payload
        export_options.metric_title = jQuery(".title_wrapper .metric_title").html().trim();
        export_options.metric_value = jQuery(".title_wrapper .metric_value").html().trim();
        //Push all the checked input fields in export list
        export_options.export_fields = {};
        jQuery("#ticket_fields input:checked").each(function(idx,el){
                export_options.export_fields[jQuery(el).val()] = jQuery(el).data('label');
        });

        var params = {
            export_params: export_options
        };

        var opts = {
                url: _this.CONST.base_url + HelpdeskReports.locals.report_type + _this.CONST.export_url,
                type: 'POST',
                dataType: 'json',
                contentType: 'application/json',
                data : Browser.stringify(params),
                success: function (data) {
                    _this.actions.flushExportSection();                   
                   jQuery(".success_message").removeClass("hide");
                            setTimeout(function() {
                                jQuery('.success_message').fadeOut('slow');
                    }, 2500);
                       
                },
                error: function (data) {
                    //_this.appendExportError();
                    _this.actions.flushExportSection();
                    jQuery(".error_message").removeClass("hide");
                    setTimeout(function() {
                        jQuery('.error_message').fadeOut('slow');
                    }, 2500); 
                }
            }
            _this.makeAjaxRequest(opts);
            trigger_event("analytics.export_ticket_list",{});
    },
    bindExportFieldEvents : function() {

        var _this = this;

        var export_fields = jQuery("#ticket_fields input[type='checkbox']");
        jQuery('#toggle_checks').on('change', function () {
                jQuery(export_fields).prop('checked', jQuery(this).is(":checked"));
        });

        //For toggling select all/none checkbox when toggling fields -->
        jQuery(export_fields).on('change', function () {
            var count = 0;
            jQuery(export_fields).each(function(i,ele){ if(ele.checked) count++; });
            jQuery('#toggle_checks').prop('checked', (jQuery(export_fields).length == count));
        });

        jQuery("#export_submit").click(function () {  

            if (jQuery('#ticket_fields :checked').length == 0) {
                jQuery('#err_no_fields_selected').removeClass('hide');
                return false;
            } else {
                jQuery('#err_no_fields_selected').addClass('hide');
                
                jQuery("#export_submit").prop('disabled', 'disabled').addClass("disabled").html("Exporting...");
                //
                _this.exportCSV();
            }
        });
    },
    toggleExportSection : function(){
            var _this = this;
            
            jQuery(".fields").slideToggle("fast",function(){
                    var is_opened = jQuery(this).is(":visible"); 
                    if(is_opened){
                        jQuery(".export_title .title").removeClass('hide');
                        jQuery(".export_title .link").addClass('hide');

                        //Fetch Ticket Fields if not done previously
                        if(HelpdeskReports.locals.export_fields == undefined ){
                            jQuery('#ticket_fields').addClass('sloading loading-small');
                            _this.fetchExportFields();
                        } 
                    }else{
                        jQuery(".export_title .title").addClass('hide');
                        jQuery(".export_title .link").removeClass('hide');
                    }
                });
    },
                    /* End of Export Section */    
    generatePdfAsync: function (){
        var _this = this;
        var params = _this.pdfParams();
        if(HelpdeskReports.locals.report_type == 'glance')
            params['active_custom_field'] = HelpdeskReports.locals.active_custom_field;
        var opts = {
            url: _this.CONST.base_url + HelpdeskReports.locals.report_type + _this.CONST.email_reports,
            type: 'POST',
            dataType: 'html',
            contentType: 'application/json',
            data: Browser.stringify(params),
            timeout: _this.timeouts.main_request,
            success: function (data) {
                var text = "<span id='email_reports_msg'>"+I18n.t('adv_reports.report_export_success')+"</span>";
                _this.showResponseMessage(text);     
            },
            error: function (data) {
                var text = "<span id='email_reports_msg'>"+I18n.t('helpdesk_reports.no_data_to_display_msg')+"</span>";
                _this.showResponseMessage(text);
            }
        }
        _this.makeAjaxRequest(opts);
    },
    pdfParams: function () {
        var _this = this;
        var pdf_params, pdf_args;
        var trend_args = _this.getTrendArgs();
            var current_params = [];
            var date = HelpdeskReports.locals.date_range;
            var filter = HelpdeskReports.locals.query_hash || [];
            pdf_args = {
                date_range: HelpdeskReports.locals.date_range,
                select_hash:  HelpdeskReports.locals.select_hash,
                trend: trend_args,
                report_filters: filter,
                direct_export: true
            }; 
        if(parseInt(jQuery(".reports-menu li.active a").attr('data-index')) > -1){
            pdf_args.filter_name = jQuery(".reports-menu li.active a").attr('data-original-title');
        }
        return pdf_args; 
    },
    showResponseMessage: function(message){
        jQuery("#email_reports_msg").remove();
        var msg_dom = jQuery("#noticeajax");
        msg_dom.empty();
        msg_dom.prepend(message);
        msg_dom.show();
        jQuery("<a />").addClass("close").attr("href", "#").appendTo(msg_dom).on('click.helpdesk_reports', function(){
            msg_dom.fadeOut(600);
            return false;
        });
        setTimeout(function() {    
            jQuery("#noticeajax a").trigger( "click" );  
            msg_dom.find("a").remove();
        }, 1200);
        
    },
    getTrendArgs: function(){
        var trend_args = {
            trend: HelpdeskReports.locals.trend,
            response_trend: HelpdeskReports.locals.response_trend,
            resolution_trend: HelpdeskReports.locals.resolution_trend
        }
        return trend_args;
    },
    flushLocals: function () {
        HelpdeskReports.locals = {};
    },
    flushEvents: function () {
        jQuery('#reports_wrapper').off('.helpdesk_reports');
        jQuery(document).off('.helpdesk_reports');
    },
    flushSavedUtil : function(){
        HelpdeskReports.SavedReportUtil.initialized = false;
        jQuery(document).off('.save_reports');
        //Delete the dialog content
        jQuery('#report-dialog-save').remove();
    },
    flushCharts: function () {
        if (Highcharts && Highcharts.charts && Highcharts.charts.length) {
            var charts = Highcharts.charts;
            for (i = 0; i < charts.length; i++) {
                if (charts[i] !== undefined)
                    charts[i].destroy();
            }
        }
    },
    flushDataTable : function(){
        fixedHeader.flush();
    },
    scrollTop: function () {
        var body = jQuery("html, body");
        body.stop().animate({scrollTop:0}, '500', 'swing');
    },
    adjustFilterButton : function() {
        if(HelpdeskReports.locals.is_non_sprout_plan) {
            var lang = jQuery("html").attr("lang");
            if(lang && lang == "zh-TW") {
                jQuery(".edit-filter").removeClass('span1').addClass('span2');
                jQuery(".filter-type").removeClass('span11').addClass('span10');
            }
        }
    },
    scrollToReports: function () {
        var body = jQuery("html, body");
        body.stop().animate({ 
            scrollTop: (jQuery('#reports_container').offset().top - 10)
        },'500','swing');
    },
    resetAndGenerate: function () {
        jQuery('#loading-box').show();
        this.flushCharts();
        this.actions.hideTicketList();
        this.actions.hideViewMore();
        this.actions.hideNestedFieldDrillDown();
        this.actions.closeFilterMenu();
        this.generateCharts(HelpdeskReports.locals.params);
    },
    // This utility function is used to show empty chart, if the data is null.
    // Note - container should be a valid id, to polulate the template.
    populateEmptyChart: function(container_id, data){
        var emptychartSection = JST["helpdesk_reports/templates/empty_chart_data"]({
             data: data
        });
        for (var i = 0; i < container_id.length; i++) {
            jQuery('#'+container_id[i]).html(emptychartSection);
        };
    },
    timeMetricConversion: function( total_seconds ){
        if(typeof total_seconds !== 'number')  return total_seconds;
        var hrs = '<span class="time-char-format">'+I18n.t('helpdesk_reports.time_shorthand.h')+'</span>';
        var mins= '<span class="time-char-format">'+I18n.t('helpdesk_reports.time_shorthand.m')+'</span>';
        var secs= '<span class="time-char-format">'+I18n.t('helpdesk_reports.time_shorthand.s')+'</span>';
        var h   = Math.floor(total_seconds / 3600);
        var min = Math.floor((total_seconds / 60) % 60);
        var sec = Math.floor(total_seconds % 60);

        return total_seconds > 3600 ? (h + hrs +' '+min + mins) : (min + mins +' '+sec + secs );
    },
    shortenLargeNumber: function(num, digits) {
        if (num <= this.SHORTEN_LIMIT) //Start using abbreviations from 10,000
            return num;
        var units = ['k', 'M', 'G', 'T', 'P', 'E', 'Z', 'Y'],
            decimal;

        for(var i=units.length-1; i>=0; i--) {
            decimal = Math.pow(1000, i+1);

            if(num <= -decimal || num >= decimal) {
                return +(num / decimal).toFixed(digits) + units[i];
            }
        }
        return num;
    },
    addsuffix: function (m) {
        if(typeof m !== 'number')  {
            return m;
        } else {
            return m + '<span class="time-char-format">%</span>';
        }
    },
    dateRangeDiff: function () {
        var diff = 0;
        var date_range = HelpdeskReports.locals.date_range.split('-');
        if (date_range.length == 2){
            diff = (Date.parse(date_range[1]) - Date.parse(date_range[0])) / (36e5 * 24);
        }else{
            diff = (Date.parse(HelpdeskReports.locals.endDate)-Date.parse(date_range[0])) / (36e5 * 24);
        }
        return diff;
    },
    getDateRangeDefinition : function(dateFormat,date_lag){

        var timezone = HelpdeskReports.locals.account_time_zone;
        return {
            1:                    moment.tz(new Date(),timezone).subtract(1,'days').format(dateFormat), 
            7:                    moment.tz(new Date(),timezone).subtract((6   + date_lag),"days").format(dateFormat),
            30:                   moment.tz(new Date(),timezone).subtract((29  + date_lag),"days").format(dateFormat),
            90:                   moment.tz(new Date(),timezone).subtract((89  + date_lag),"days").format(dateFormat),
            endDate:              moment.tz(new Date(),timezone).subtract(date_lag,"days").format(dateFormat),
            end_date_with_no_lag: moment.tz(new Date(),timezone).format(dateFormat),
            this_week_start:      moment.tz(new Date(),timezone).startOf('isoWeek').format(dateFormat),
            previous_week_start:  moment.tz(new Date(),timezone).subtract(1, 'weeks').startOf('isoWeek').format(dateFormat),
            previous_week_end:    moment.tz(new Date(),timezone).subtract(1, 'weeks').endOf('isoWeek').format(dateFormat),
            this_month_start:     moment.tz(new Date(),timezone).startOf('month').format(dateFormat),
            previous_month_start: moment.tz(new Date(),timezone).subtract(1,'months').startOf('month').format(dateFormat),
            previous_month_end:   moment.tz(new Date(),timezone).subtract(1,'months').endOf('month').format(dateFormat),
            last_3_months:        moment.tz(new Date(),timezone).subtract(date_lag,"days").subtract(2,'months').startOf('month').format(dateFormat),
            last_6_months:        moment.tz(new Date(),timezone).subtract(date_lag,"days").subtract(5,'months').startOf('month').format(dateFormat),
            this_year_start:      moment.tz(new Date(),timezone).startOf('year').format(dateFormat),
        }
    },
    setDiff: function(arr1, arr2){
        var res = arr1;
        for(i=0; i< arr1.length; i++){
            res[i] = res[i] - arr2[i]
        }
        return res;
    }
};