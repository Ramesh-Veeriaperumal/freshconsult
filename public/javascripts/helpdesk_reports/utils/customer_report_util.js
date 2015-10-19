HelpdeskReports.ReportUtil = HelpdeskReports.ReportUtil || {};

HelpdeskReports.ReportUtil.CustomerReport = (function () {
    var _FD = {
        bindEvents: function () {
            jQuery('#reports_wrapper').on('click.helpdesk_reports', "[data-action='reports-submit']", function () {
                _FD.actions.submitReports();
            });

            jQuery(document).on("customer_report_ticket_list.helpdesk_reports", function (ev, data) {
                var flag = HelpdeskReports.locals.ticket_list_flag;
                if (flag == false) {
                    HelpdeskReports.locals.ticket_list_flag = true;
                    _FD.core.actions.showTicketList();
                    _FD.constructTicketListParams(data);
                }
            });
        },
        actions: {
            submitReports: function () {
                var flag = _FD.core.refreshReports();
                
                if(flag) {
                    _FD.flushEvents();
                    _FD.core.resetAndGenerate();
                }
            }
        },
        constructTicketListParams: function (data) {
            HelpdeskReports.locals.list_params = [];
            var list_params = HelpdeskReports.locals.list_params;
            var conditions = [];
            
            var list_hash = {
                date_range: HelpdeskReports.locals.date_range,
                filter: HelpdeskReports.locals.query_hash,
                list: true,
                list_conditions: [],
                metric: data.metric
            }

            var main_condition = _FD.constructMainListCondition(data.label);

            if(!jQuery.isEmptyObject(main_condition)) {
                list_hash.list_conditions.push(main_condition);
            }

            if (_FD.constants.percentage_metrics.indexOf(data.metric) > -1) {
                var supplement_condition = {
                    condition : _FD.constants.metrics[data.metric].ticket_list_metric,
                    operator : 'is',
                    value : true 
                };
                list_hash.list_conditions.push(supplement_condition);
            }

            var hash = jQuery.extend({},_FD.constants.params, list_hash);
            list_params.push(hash);
            _FD.core.fetchTickets(list_params);
        },
        constructMainListCondition: function (label) {
            var list_hash = {};
            var hash_values = {};
            var company_options = HelpdeskReports.locals.report_field_hash['company_id'].options;

            _.map(company_options, function(val){                     
                hash_values[val[1]] = val[0]; 
            });

            if (hash_values.hasOwnProperty(label)) {
                var string_val = hash_values[label].toString();

                list_hash = {
                    condition : 'company_id',
                    operator: 'eql',
                    value: string_val
                }
            }    
            return list_hash;
        },
        setDefaultValues: function () {
            var current_params = [];
            var date = _FD.core.setReportFilters();
            jQuery.each(_.keys(_FD.constants.metrics), function (index, value) {
                var merge_hash = {
                    metric: value,
                    filter:[],
                    date_range: date
                } 
                var params = jQuery.extend({}, _FD.constants.params, merge_hash);
                current_params.push(params);

            });
            HelpdeskReports.locals.params = current_params.slice();
            _FD.actions.submitReports();
        },
        flushEvents: function () {
            jQuery('#reports_wrapper').off('.cust');
        }
    };
    return {
        init: function () {
            _FD.core = HelpdeskReports.CoreUtil;    
            _FD.constants = jQuery.extend({}, HelpdeskReports.Constants.CustomerReport);
            _FD.bindEvents();
            _FD.setDefaultValues();
        }
    };
})();