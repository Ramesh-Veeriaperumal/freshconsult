HelpdeskReports.ReportUtil = HelpdeskReports.ReportUtil || {};

HelpdeskReports.ReportUtil.TicketVolume = (function () {
    var _FD = {
        bindEvents: function () {
            jQuery('#reports_wrapper').on('click.helpdesk_reports', "[data-action='reports-submit']", function () {
                _FD.actions.submitReports();
            });
            jQuery(document).on("timetrend_point_click.helpdesk_reports", function (ev, data) {
                var flag = HelpdeskReports.locals.ticket_list_flag;
                if (flag == false) {
                    if (data.sub_metric && data.date && HelpdeskReports.locals.trend) {
                        HelpdeskReports.locals.ticket_list_flag = true;
                        _FD.getTicketListTitle(data);
                        _FD.constructTicketListParams(data.sub_metric, data.date, HelpdeskReports.locals.trend);
                    }
                }
            });
        },
        getTicketListTitle : function(data){
                var title = "";
                if( data.sub_metric == "RECEIVED_TICKETS"){
                    title = "Tickets Received" ;
                }else{
                    title = "Tickets Resolved" ;
                }
                var value = data.date + " : " + data.value;
                _FD.core.actions.showTicketList(title,value);
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
        constructTicketListParams: function (sub_metric, date, trend) {
            HelpdeskReports.locals.list_params = [];
            var list_params = HelpdeskReports.locals.list_params;

            var list_hash = {
                date_range: HelpdeskReports.locals.date_range,
                filter: HelpdeskReports.locals.query_hash,
                list: true,
                list_conditions: [],
                metric: sub_metric
            }

            list_hash.list_conditions.push({
                condition: trend,
                operator: 'is_in',
                value: date
            });

            var hash = jQuery.extend({},_FD.constants.params, list_hash);
            list_params.push(hash);

            _FD.core.fetchTickets(list_params);

        },
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
            HelpdeskReports.locals.params = current_params.slice();
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
            _FD.bindEvents();
            _FD.core.ATTACH_DEFAULT_FILTER = true;
            _FD.setDefaultValues();
            
        }
    };
})();