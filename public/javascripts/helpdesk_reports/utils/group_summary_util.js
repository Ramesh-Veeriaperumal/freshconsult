HelpdeskReports.ReportUtil = HelpdeskReports.ReportUtil || {};

HelpdeskReports.ReportUtil.GroupSummary = (function () {
    var _FD = {
        bindEvents: function () {
            jQuery('#reports_wrapper').on('click.helpdesk_reports', "[data-action='reports-submit']", function () {
                _FD.actions.submitReports();
            });

            jQuery('#reports_wrapper').on('click.helpdesk_reports', '[data-table="ticket-data"] td:not(".disable")', function () {
                var flag = HelpdeskReports.locals.ticket_list_flag;
                if (flag == false) {
                    HelpdeskReports.locals.ticket_list_flag = true;
                    var el = this;
                    _FD.core.actions.showTicketList();
                    _FD.constructTicketListParams(el);
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
        constructTicketListParams: function (el) {
            var metric = jQuery(el).data('metric-name');
            var value = jQuery(el).data('group-id');
            var condition = _FD.constants.group_by;

            HelpdeskReports.locals.list_params = [];
            var list_params = HelpdeskReports.locals.list_params;

            var list_hash = {
                date_range: HelpdeskReports.locals.date_range,
                filter: HelpdeskReports.locals.query_hash,
                list: true,
                list_conditions: [],
                metric: metric
            }

            list_hash.list_conditions.push({
                condition: condition,
                operator: 'eql',
                value: value
            });
            
            var index = _FD.constants.percentage_metrics.indexOf(metric);
            if (index > -1) {
                var supplement_condition = {
                    condition : _FD.constants.ticket_list_metric[index],
                    operator : 'is',
                    value : false 
                };
                list_hash.list_conditions.push(supplement_condition);
            }

            var hash = jQuery.extend({}, _FD.constants.params, list_hash);
            list_params.push(hash);

            _FD.core.fetchTickets(list_params);

        },
        setDefaultValues: function () {
            var current_params = [];
            var date = _FD.core.setReportFilters();
            jQuery.each(_FD.constants.metrics, function (index, value) {
                var merge_hash = {
                    metric: value,
                    filter: [],
                    date_range: date,
                    group_by: []
                }
                merge_hash.group_by.push(_FD.constants.group_by);
                var param = jQuery.extend({}, _FD.constants.params, merge_hash);
                current_params.push(param);
            });
            HelpdeskReports.locals.params = current_params.slice();
            _FD.actions.submitReports();
        },
        flushEvents: function () {
            jQuery('#reports_wrapper').off('.group');
        }
    };
    return {
        init: function () {
                _FD.core = HelpdeskReports.CoreUtil;
                _FD.constants = HelpdeskReports.Constants.GroupSummary;
                _FD.bindEvents();
                _FD.setDefaultValues();
        }
    };
})();