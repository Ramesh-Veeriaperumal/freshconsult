HelpdeskReports.CoreUtil = HelpdeskReports.CoreUtil || {}

HelpdeskReports.ReportUtil = HelpdeskReports.ReportUtil || {};

// TODO: Remove all prototype.js based dependencies in the Report code.
HelpdeskReports.CoreUtil = {
    query_hash: [],
    select_hash: [],
    MULTI_SELECT_SELECTION_LIMIT: 10,
    TICKET_FILTER_LIMIT: 10,
    _const: {
        base_url    : "/reports/v2/",
        metrics_url : "/fetch_metrics",
        tickets_url : "/fetch_ticket_list",
        field_menu  : "report-fields-menu"
    },
    getFilterDisplayData: function () {
        var _this = this;
        _this.select_hash = [];
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
                _this.select_hash.push({
                    name: data_label,
                    value: values
                });
            }
        });
        _this.setFilterDisplayData();
    },
    // TODO: Move all markup based processing into JSTs
    setFilterDisplayData: function () {
        var filter_obj  = this.select_hash;
        var filter_html = "<li class='muted'>Filtered by:</li>";
        if (filter_obj && filter_obj.length) {
            jQuery.each(filter_obj, function (index, filter) {
                filter_html += "<li>" + filter.name + " : <strong>" + escapeHtml(filter.value) + "</strong></li>";
            });
        }
        filter_html += "<li>Time Period : <strong>" + jQuery("#date_range").val() + "</strong></li>";
        jQuery(".filter-type ul").html(filter_html);
    },
    setFilterData: function () {
        var _this = this;
        _this.query_hash = [];
        var local_hash = [];
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
                _this.query_hash.push({
                    condition: this.getAttribute("condition"),
                    operator: this.getAttribute("operator"),
                    value: value.toString()
                });
                //local_hash is filters stored in localStorage for populating on load.
                if (container === 'nested_field' && _this.custom_field_hash.hasOwnProperty(condition)) {
                    var nested_values = [];
                    for (i = 0; i < _this.custom_field_hash[condition].length; i++) {
                        var values = jQuery('#div_ff_' + _this.custom_field_hash[condition][i]).find('select').val();
                        nested_values.push(values);
                    }
                    local_hash.push({
                        condition: this.getAttribute("condition"),
                        operator: this.getAttribute("operator"),
                        value: nested_values
                    });
                } else if (container !== 'nested_field') {
                    local_hash.push({
                        condition: this.getAttribute("condition"),
                        operator: this.getAttribute("operator"),
                        value: value.toString()
                    });
                }
            } else {
                //Removing fields with no values in filters by triggering click.
                jQuery('#div_ff_' + condition).find('i.ficon-cross').click();
            }
        });
        jQuery.each(_this.params, function (index) {
            _this.params[index]['filter'] = _this.query_hash;
        });

        // TODO: Consider mode this to a cache util.
        // Cache.get(key) / Cache.set(key, data)
        if (typeof (Storage) !== "undefined") {
            window.localStorage.setItem('reports-filters', local_hash.toJSON());
        }
    },
    dateChanged: function () {
        var _this = this;
        var date = jQuery('#date_range').val();
        jQuery.each(_this.params, function (index) {
            _this.params[index]['date_range'] = date;
        });
        if (typeof (Storage) !== "undefined") {
            window.localStorage.setItem('reports-dateRange', date);
        }
    },
    refreshReports: function () {
        var _this = this;
        _this.setFilterData();
        _this.getFilterDisplayData();
        _this.dateChanged();
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
    // TODO: 
    // 1. Move all binding inner methods to a member hash eg: actions: {} and map them to the events.
    // 2. Have namespaced events eg: click.helpdesk_reports.
    // 3. Map event delecations to custom attributes such as [data-actions=close] rather than having them mapped to visual attributes that may change.
    // 4. Delegate the events to a patent containter rather than document.
    bindEvents: function () {
        var _this = this;
        jQuery('.report-fields-selector').on('click', function () {
            if (!jQuery('.' + _this._const.field_menu).is(':visible') && jQuery('.' + _this._const.field_menu + ' ul li').length !== 0) {
                jQuery('.' + _this._const.field_menu).show();
            } else {
                jQuery('.' + _this._const.field_menu).hide();
            }
        });
        jQuery('.' + _this._const.field_menu).on('click', 'li', function () {
            var selected = jQuery(this).data('menu');
            _this.constructReportField(selected, "");
        });
        jQuery(document).on('click', '.filter-field i.ficon-cross', function () {
            var field = jQuery(this).closest('.filter-field');
            _this.removeReportField(field.attr('condition'), field.attr('data-label'));
        });
        jQuery('.title-dropdown').on('click', function (event) {
            event.stopImmediatePropagation();
            if (!jQuery('.reports-menu').is(':visible')) {
                jQuery('.reports-menu').removeClass('hide');
            } else {
                jQuery('.reports-menu').addClass('hide');
            }
        });
        jQuery(document).on('click', function () {
            if (jQuery('.reports-menu').is(':visible')) {
                jQuery('.reports-menu').addClass('hide');
            }
        });
        jQuery('#metric-edit').on('click', function () {
            _this.animateBlock(0, 'report-filters-container');
        });
        jQuery('.metric-header .close').on('click', function () {
            _this.animateBlock('-400', 'report-filters-container');
            if (jQuery('.' + _this._const.field_menu).is(':visible')) {
                jQuery('.' + _this._const.field_menu).hide();
            }
        });
        jQuery('.ticket-list-wrapper .cross').on('click', function () {
            _this.animateright('-570', 'ticket-list-wrapper');
        });
        _this.addIndexToFields();
        _this.generateReportFiltersMenu();
        _this.customFieldHash();
        _this.scrollTop();
    },
    addIndexToFields: function () {
        var hash = this.ticket_field_hash;
        var index = 0;
        for (var key in hash) {
            hash[key].position = index;
            index++;
        }
    },
    customFieldHash: function () {
        var _this = this;
        var hash = _this.ticket_field_hash;
        _this.custom_field_hash = {};
        for (var key in hash) {
            if (hash[key]['field_type'] === 'custom' && hash[key]['container'] === 'nested_field') {
                var fields = [];
                fields.push(hash[key]['condition']);
                for (i = 0; i < hash[key]['nested_fields'].length; i++) {
                    fields.push(hash[key]['nested_fields'][i]['condition']);
                }
                _this.custom_field_hash[key] = fields;
            } else if (hash[key]['field_type'] === 'custom' && hash[key]['container'] === 'multi_select') {
                _this.custom_field_hash[key] = [];
            }
        }
    },
    generateReportFiltersMenu: function () {
        var _this = this;
        var filter_html = "";
        for (var i in _this.ticket_field_hash) {
            filter_html += "<li data-position='" + _this.ticket_field_hash[i].position + "' data-menu='" + _this.ticket_field_hash[i].condition + "'>" + _this.ticket_field_hash[i].name + "</li>";
        }
        jQuery('.' + _this._const.field_menu + ' ul').html(filter_html);
    },
    // TODO: Can consider moving this to CSS translate/animation
    animateBlock: function (distance, block) {
        if (jQuery('html').attr('dir') === 'rtl') {
            jQuery('.' + block).animate({
                right: distance
            });
        } else {
            jQuery('.' + block).animate({
                left: distance
            });
        }
    },
    // TODO: Can consider moving this to CSS translate/animation
    animateright: function (distance, block) {
        if (jQuery('html').attr('dir') === 'rtl') {
            jQuery('.' + block).animate({
                left: distance
            });
        } else {
            jQuery('.' + block).animate({
                right: distance
            });
        }
    },
    // TODO: Refactor by move them into smaller utils.
    // EG. getting the initValue of nested field can be a util method.
    constructReportField: function (field, val) {
        var _this = this;
        var _this_hash = _this.ticket_field_hash;
        var present = jQuery('#active-report-filters').find(jQuery('[condition=' + field + ']'));
        if (field in _this_hash && !present.length) {
            var field_hash = _this_hash[field];
            field_hash.active = true;
            if (field_hash.container && field_hash.container === 'nested_field') {
                var tmpl = JST["helpdesk_reports/templates/nested_field_tmpl"](field_hash);
                jQuery(tmpl).appendTo('#active-report-filters');
                jQuery('#' + field_hash.field_id + '_category').nested_select_tag({
                    initValues: {
                        "category_val"    : val.length && val[0] !== null ? val[0] : null,
                        "subcategory_val" : val.length && val[1] !== null ? val[1] : null,
                        "item_val"        : val.length && val[2] !== null ? val[2] : null
                    },
                    default_option: "<option value=''>...</option>",
                    data_tree: field_hash.options,
                    subcategory_id: field_hash.field_id + '_sub_category',
                    item_id: field_hash.field_id + '_item_sub_category'
                });
            } else {
                var tmpl = JST["helpdesk_reports/templates/multiselect_tmpl"](field_hash);
                jQuery(tmpl).appendTo('#active-report-filters');
                jQuery("#" + field_hash.condition).select2({
                    maximumSelectionSize: _this.MULTI_SELECT_SELECTION_LIMIT
                });
                if (val.length) {
                    jQuery("#" + field_hash.condition).select2('val', val.split(','));
                }
            }
            // TODO: Move the below into a seperate Method
            jQuery('.' + _this._const.field_menu + ' li[data-menu="' + field + '"]').remove();
        }

        // Hide filter menu when all fields selected
        // TODO: Move this as a toggle method so that it will be called when we remove a field/an selection item.
        if (!jQuery('.' + _this._const.field_menu + ' li').length) {
            jQuery('.report-fields-selector').hide();
            jQuery('.' + _this._const.field_menu).hide();
        }

    },
    removeReportField: function (condition, dataLabel) {
        var _this = this;
        if (condition.length && dataLabel.length && !jQuery('.' + _this._const.field_menu + '[data-menu="' + condition + '"]').length) {
            jQuery('#div_ff_' + condition).remove();
            var field = '<li data-position="' + _this.ticket_field_hash[condition].position + '" data-menu="' + condition + '">' + dataLabel + '</li>';
            jQuery('.' + _this._const.field_menu + ' ul').append(field);
            _this.ticket_field_hash[condition]["active"] = false;
        }
        //Show filter menu when all fields not selected
        if (jQuery('.report-fields-menu li').length && !jQuery('.report-fields-selector').is(':visible')) {
            jQuery('.report-fields-selector').show();
        }
        _this.sortFilterMenu();
    },
    sortFilterMenu: function (b, a) {
        var list = jQuery('.report-fields-menu ul li');
        var listItems = list.sort(function (a, b) {
            return (jQuery(b).data('position')) < (jQuery(a).data('position')) ? 1 : -1;
        }).appendTo('.report-fields-menu ul');
    },
    setReportTitle: function (title) {
        var type = this.report_type;
        jQuery('.reports-menu li[data-report="' + type + '"]').addClass('active');
        jQuery('#report-title').text(title);
    },
    setReportFilters: function () {
        var _this = this;
        var filter = [];
        var date;
        if (typeof (Storage) !== "undefined" && localStorage.getItem('reports-filters') !== null) {
            filter = JSON.parse(localStorage.getItem('reports-filters'));
        }
        if (typeof (Storage) !== "undefined" && localStorage.getItem('reports-dateRange') !== null) {
            date = localStorage.getItem('reports-dateRange');
        } else {
            date = jQuery('#date_range').val();
        }
        if (date !== jQuery('#date_range').val()) {
            jQuery('#date_range').val(date);
        }
        _this.constructDateRangePicker();
        if (filter.length) {
            jQuery(filter).each(function (index, hash) {
                if (_this.ticket_field_hash.hasOwnProperty(hash.condition)) {
                    _this.constructReportField(hash.condition, hash.value);
                }
            });
        }
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

        jQuery("#date_range").bind('keypress keyup keydown', function (ev) {
            ev.preventDefault();
            return false;
        });
    },
    generateCharts: function (params) {
        var _this = this;
        _this.scrollTop();
        var opts = {
            url: _this._const.base_url + _this.report_type + _this._const.metrics_url,
            type: 'POST',
            dataType: 'html',
            contentType: 'application/json',
            data: Browser.stringify(params),
            success: function (data) {
                jQuery('.reports-container').html(data);
                jQuery('#loading-box').hide();
            },
            error: function (data) {
                jQuery('.reports-container').html(data);
                jQuery('#loading-box').hide();
            }
        }
        _this.makeAjaxRequest(opts);
    },
    fetchTickets: function (params) {
        var _this = this;
        var opts = {
            url: _this._const.base_url + _this.report_type + _this._const.tickets_url,
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
    // TODO: Have a flush events metod.
    flushContainers: function () {
        if (Highcharts && Highcharts.charts && Highcharts.charts.length) {
            var charts = Highcharts.charts;
            for (i = 0; i < charts.length; i++) {
                if (charts[i] !== undefined)
                    charts[i].destroy();
            }
        }
    },
    scrollTop: function () {
        window.scrollTo(0, 0);
    }
};


HelpdeskReports.ReportUtil.TicketVolume = (function () {
    var _FD = {
        bindEvents: function () {
            jQuery("#submit").on('click', function () {
                _FD.core_util.refreshReports();
                _FD.core_util.flushContainers();
                jQuery('.ticket-list-wrapper .cross').click();
                jQuery('#loading-box').show();
                _FD.core_util.generateCharts(_FD.core_util.params);
                jQuery('.metric-header .close').click();
            });
            //Commenting out ticket_list code for first cut
            // jQuery(document).on("timetrend_point_click", function (ev, data) {
            //     if (data.sub_metric && data.date && _FD.core_util.trend) {
            //         _FD.modifyTicketParams(data.sub_metric, data.date, _FD.core_util.trend);
            //         jQuery("#ticket_list").html("").addClass('sloading loading-small');
            //         _FD.core_util.animateright(0, 'ticket-list-wrapper');
            //     }
            // });
        },
        modifyTicketParams: function (sub_metric, date, trend) {
            jQuery.each(_FD.core_util.params, function (i) {
                var reset_param = {
                    list: true,
                    list_conditions: [],
                    metric: sub_metric
                }
                reset_param.list_conditions.push({
                    condition: trend,
                    operator: 'is_in',
                    value: date
                })
                jQuery.extend(_FD.core_util.params[i], reset_param);
            });
            _FD.core_util.fetchTickets(_FD.core_util.params);
            _FD.resetTicketListParams();
        },
        resetTicketListParams: function () {
            jQuery.each(_FD.core_util.params, function (i) {
                var reset_param = {
                    list: false,
                    list_conditions: [],
                    metric: _FD.core_util.metric
                }
                jQuery.extend(_FD.core_util.params[i], reset_param);
            });
        },
        setDefaultValues: function () {
            var current_params = [];
            var date = _FD.core_util.setReportFilters();
            jQuery.each(_FD.constants.metrics, function (index, value) {
                var merge_hash = {
                    metric: value,
                    report_type: _FD.constants.report_type,
                    filter: [],
                    date_range: date
                }
                var param = jQuery.extend({}, _FD.constants.params, merge_hash);
                current_params.push(param);
            });
            _FD.core_util.params = current_params;
            jQuery('#submit').click();
        }
    };
    return {
        init: function (opts) {
            _FD.core_util = HelpdeskReports.CoreUtil;
            _FD.core_util.setReportTitle(opts['title']);
            _FD.core_util.metric = opts['metric'];
            _FD.constants = HelpdeskReports.Constants.TicketVolume;
            _FD.core_util.report_type = _FD.constants.report_type;
            _FD.bindEvents();
            _FD.setDefaultValues();
        }
    };
})();