HelpdeskReports.CoreUtil = HelpdeskReports.CoreUtil || {};
HelpdeskReports.locals = HelpdeskReports.locals || {};

HelpdeskReports.CoreUtil = {
    MULTI_SELECT_SELECTION_LIMIT: 10,
    FILTER_LIMIT: 5,
    FILTER_LIMIT_MSG: "* You can select a maximum of 5 filters. (Each level of nested field counts as one filter)",
    CONST: {
        base_url    : "/reports/v2/",
        metrics_url : "/fetch_metrics",
        tickets_url : "/fetch_ticket_list"
    },
    getFilterDisplayData: function () {
        var _this = this;
        HelpdeskReports.locals.select_hash = [];
        jQuery("#active-report-filters div.ff_item").map(function () {
            var container  = this.getAttribute("container");
            var data_label = this.getAttribute("data-label");
            var value;

            if (container == "nested_field") {
                value = jQuery(this).children('select').find('option:selected').text();
            } else {
                value = jQuery(this).find('option:selected').map(function () {
                    return jQuery(this).text();
                }).get();
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
        var tmpl = JST["helpdesk_reports/templates/filter_data_template"]({ 
            data: HelpdeskReports.locals.select_hash 
        });
        jQuery("#filter_text").html(tmpl);
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
            var value;

            if (container == "nested_field") {
                value = (jQuery(this).children('select').val() === null ? "" : jQuery(this).children('select').val());
            } else if (container == "multi_select" || container == "select") {
                value = jQuery(this).find('option:selected').map(function () {
                    return this.value;
                }).get();
            }
            if (value.length) {
                locals.query_hash.push({
                    condition: condition,
                    operator: operator,
                    value: value.toString()
                });
                //local_hash is filters stored in localStorage for populating on load.
                var hash = _this.getLocalHash(condition, container, operator, value);
                locals.local_hash.push(hash);
            } else {
                //Removing fields with no values in filters by triggering click.
                var active = jQuery('#div_ff_' + condition);
                if (active.attr('data-type') && active.attr('data-type') === "filter-field") {
                    _this.actions.removeField(active);
                }
            }
        });
        
    },
    afterFilterValidation: function () {
        var _this = this;
        var locals = HelpdeskReports.locals;

        jQuery.each(locals.params, function (index) {
            locals.params[index]['filter'] = locals.query_hash;
        });

        // TODO: Consider mode this to a cache util.
        // Cache.get(key) / Cache.set(key, data)
        if (typeof (Storage) !== "undefined") {
            window.localStorage.setItem('reports-filters', locals.local_hash.toJSON());
        }

        _this.getFilterDisplayData();
        _this.dateChanged();

        if (locals.report_type == 'glance') {
            _this.glanceGroupByFieldsInit();
        }
    },
    getLocalHash: function (condition, container, operator, value) {
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

        return hash;
    },
    /*TODO: Need to simplify following methods.
      GlanceReport -  groupby field methods start */
    glanceGroupByFieldsInit: function () {
        var locals = HelpdeskReports.locals;
        if (!jQuery.isEmptyObject(locals.custom_field_hash)) {
            this.getCumtomFieldsInFilters();
        } else {
            this.GroupByNonCustomFieldAcnt();
        }
    },
    getCumtomFieldsInFilters: function () {
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
                        if(val === null || val === ""){
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
        
        var current_group = this.setDefaultGroupByOptions();
        
        if (locals.custom_fields_group_by.length) {
            current_group.push(locals.custom_fields_group_by[0]);
        }
        locals.current_group_by = current_group;
    },
    GroupByNonCustomFieldAcnt: function () {
        var locals = HelpdeskReports.locals;
        locals.custom_fields_group_by = [];
        locals.current_group_by = this.setDefaultGroupByOptions();
    },
    setDefaultGroupByOptions: function () {
        var groupby = [];
        var constants = jQuery.extend({}, HelpdeskReports.Constants.Glance);

        if (constants.status_metrics.indexOf(HelpdeskReports.locals.active_metric) > -1) {
            groupby = constants.group_by_with_status.slice();
        } else {
            groupby = constants.group_by_without_status.slice();
        }
        return groupby;
    },
    // GlanceReport -  groupby fields ends
    dateChanged: function () {
        var locals = HelpdeskReports.locals;
        var date = jQuery('#date_range').val();
        locals.date_range = date;
        jQuery.each(locals.params, function (index) {
            locals.params[index]['date_range'] = date;
        });
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
            _this.actions.openFilterMenu();
        });
        jQuery('#reports_wrapper').on('click.helpdesk_reports', '[data-action="close-filter-menu"]', function () {
            _this.actions.closeFilterMenu();
        });
        jQuery('#reports_wrapper').on('click.helpdesk_reports', '[data-action="hide-ticket-list"]', function () {
            _this.actions.hideTicketList();
        }); 
        jQuery('#reports_wrapper').on('keypress.helpdesk_reports keyup.helpdesk_reports keydown.helpdesk_reports', "#date_range", function (ev) {
            _this.actions.disableKeyPress(ev);
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
        _this.addIndexToFields();
        _this.generateReportFiltersMenu();
        _this.customFieldHash();
        _this.scrollTop();
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
        },
        hideTicketList: function () {
            jQuery('#ticket_list_wrapper').removeClass('active');
        },
        hideViewMore: function(){
            jQuery('#view_more_wrapper').removeClass('show-all-metrics');
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
        jQuery("#report_fields_list" + ' ul').html(menu_tmpl);
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
        jQuery("#" + field_hash.condition).select2({
            maximumSelectionSize: _this.MULTI_SELECT_SELECTION_LIMIT
        });
        if (val.length) {
            jQuery("#" + field_hash.condition).select2('val', val.split(','));
        }
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
        
        if (typeof (Storage) !== "undefined" && localStorage.getItem('reports-filters') !== null) {
            filter = JSON.parse(localStorage.getItem('reports-filters'));
        }
        
        if (filter.length) {
            jQuery(filter).each(function (index, hash) {
                if (HelpdeskReports.locals.report_field_hash.hasOwnProperty(hash.condition)) {
                    _this.constructReportField(hash.condition, hash.value);
                }
            });
        }

        var date = jQuery('#date_range').val();
        _this.constructDateRangePicker();

        return date;
    },
    constructDateRangePicker: function () {
        jQuery("#date_range").daterangepicker({
            earliestDate: Date.parse('04/01/2013'),
            latestDate: Date.parse('Today'),
            presetRanges: [{
                text: 'Last 7 Days',
                dateStart: 'Today-6',
                dateEnd: 'Today'
            }, {
                text: 'Last 30 Days',
                dateStart: 'Today-29',
                dateEnd: 'Today'
            }, {
                text: 'Last 90 Days',
                dateStart: 'Today-89',
                dateEnd: 'Today'
            }],
            presets: {
                dateRange: 'Date Range'
            },
            rangeStartTitle: 'Start Date',
            rangeEndTitle: 'End Date',
            dateFormat: getDateFormat('datepicker'),
            closeOnSelect: true,
        });
    },
    generateCharts: function (params) {
        var _this = this;
        _this.scrollTop();
        var opts = {
            url: _this.CONST.base_url + HelpdeskReports.locals.report_type + _this.CONST.metrics_url,
            type: 'POST',
            dataType: 'html',
            contentType: 'application/json',
            data: Browser.stringify(params),
            timeout: 45000,
            success: function (data) {
                jQuery('#view_more_wrapper').removeClass('hide');
                jQuery('#reports_wrapper').removeClass('hide');
                jQuery("#reports_container").html(data);
                jQuery('#loading-box').hide();
            },
            error: function (data) {
                jQuery('#view_more_wrapper').removeClass('hide');
                jQuery('#reports_wrapper').removeClass('hide');
                var text = "Something went wrong, please try again";
                _this.populateEmptyChart(["reports_container"], text);
                jQuery('#loading-box').hide();
            }
        }
        _this.makeAjaxRequest(opts);
    },
    fetchTickets: function (params) {
        var _this = this;
        var opts = {
            url: _this.CONST.base_url + HelpdeskReports.locals.report_type + _this.CONST.tickets_url,
            type: 'POST',
            dataType: 'json',
            contentType: 'application/json',
            data: Browser.stringify(params),
            success: function (data) {
                _this.appendTicketList(data);
            },
            error: function (data) {
                console.log(data.responseText);
                console.log('fired AJaX error');
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
    flushLocals: function () {
        HelpdeskReports.locals = {};
    },
    flushEvents: function () {
        jQuery('#reports_wrapper').off('.helpdesk_reports');
        jQuery(document).off('.helpdesk_reports');
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
    scrollTop: function () {
        var body = jQuery("html, body");
        body.stop().animate({scrollTop:0}, '500', 'swing');
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
    }
};