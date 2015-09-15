HelpdeskReports.ReportUtil = HelpdeskReports.ReportUtil || {};

HelpdeskReports.ReportUtil.TicketVolume = (function () {
    var _FD = {
        bindEvents: function () {
            jQuery('#reports_wrapper').on('click.helpdesk_reports', "[data-action='reports-submit']", function () {
                _FD.actions.submitReports();
            });
            //Commenting out ticket_list code for first cut
            // jQuery('#reports_wrapper').on("timetrend_point_click.helpdesk_reports", function (ev, data) {
            //     if (data.sub_metric && data.date && HelpdeskReports.locals.trend) {
            //         _FD.modifyTicketListParams(data.sub_metric, data.date, HelpdeskReports.locals.trend);
            //         jQuery("#ticket_list").html("").addClass('sloading loading-small');
            //         _FD.core.animateright(0, 'ticket-list-wrapper');
            //     }
            // });
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
        // modifyTicketListParams: function (sub_metric, date, trend) {
        //     jQuery.each(HelpdeskReports.locals.params, function (i) {
        //         var reset_param = {
        //             list: true,
        //             list_conditions: [],
        //             metric: sub_metric
        //         }
        //         reset_param.list_conditions.push({
        //             condition: trend,
        //             operator: 'is_in',
        //             value: date
        //         })
        //         jQuery.extend(HelpdeskReports.locals.params[i], reset_param);
        //     });
        //     _FD.core.fetchTickets(HelpdeskReports.locals.params);
        //     _FD.resetTicketListParams();
        // },
        // resetTicketListParams: function () {
        //     jQuery.each(HelpdeskReports.locals.params, function (i) {
        //         var reset_param = {
        //             list: false,
        //             list_conditions: [],
        //             metric: HelpdeskReports.locals.metric
        //         }
        //         jQuery.extend(HelpdeskReports.locals.params[i], reset_param);
        //     });
        // },
        setDefaultValues: function () {
            var current_params = [];
            var date = _FD.core.setReportFilters();
            jQuery.each(_FD.constants.metrics, function (index, value) {
                var merge_hash = {
                    date_range: date,
                    filter: [],
                    metric: value
                }
                var param = jQuery.extend({}, _FD.constants.params, merge_hash);
                current_params.push(param);
            });
            HelpdeskReports.locals.params = current_params;
            _FD.actions.submitReports();
        },
        flushEvents: function () {
            jQuery('#reports_wrapper').off('.vol');
        }
    };
    return {
        init: function () {
            _FD.core = HelpdeskReports.CoreUtil;    
            _FD.constants = jQuery.extend({}, HelpdeskReports.Constants.TicketVolume);
            HelpdeskReports.locals.metric = _FD.constants.metric;
            HelpdeskReports.locals.report_type = _FD.constants.report_type;
            _FD.bindEvents();
            _FD.setDefaultValues();
        }
    };
})();