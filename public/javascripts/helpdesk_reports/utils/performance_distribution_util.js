HelpdeskReports.ReportUtil = HelpdeskReports.ReportUtil || {};

HelpdeskReports.ReportUtil.PerformanceDistribution = (function () {
    var _FD = {
        bindEvents: function () {
            jQuery('#reports_wrapper').on('click.helpdesk_reports', "[data-action='reports-submit']", function () {
                _FD.actions.submitReports();
            });
            jQuery(document).on("perf_ticket_list.helpdesk_reports", function (ev, data) {
                var flag = HelpdeskReports.locals.ticket_list_flag;
                if (flag == false) {
                    HelpdeskReports.locals.ticket_list_flag = true;
                    _FD.getTicketListTitle(data);
                    _FD.constructTicketListParams(data);
                }
            });
        },
        getTicketListTitle : function(data){
            
            var title = "";
            var metric_name = data.metric;

            if(metric_name == "AVG_FIRST_RESPONSE_TIME"){
                
                title = HelpdeskReports.locals.first_response_time_label;

            } else if( metric_name == "AVG_RESPONSE_TIME"){

                title = HelpdeskReports.locals.avg_response_time_label ;

            } else if( metric_name == "AVG_RESOLUTION_TIME" ){

                title = HelpdeskReports.locals.resolution_bar_label;
            }
            var value = data.category + " : " + data.y;
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
        constructTicketListParams: function (data) {
            HelpdeskReports.locals.list_params = [];
            var list_params = HelpdeskReports.locals.list_params;

            var list_hash = {
                bucket: true,
                date_range: HelpdeskReports.locals.date_range,
                filter: HelpdeskReports.locals.query_hash,
                list: true,
                list_conditions: [],
                metric: data.metric
            }

            list_hash.list_conditions.push({
                condition: data.bucket,
                operator: data.operator,
                value: data.value
            });

            var hash = jQuery.extend({},_FD.constants.params, list_hash);
            list_params.push(hash);

            _FD.core.fetchTickets(list_params);

        },
       setDefaultValues: function () {
            var current_params = [];
            var date = _FD.core.setReportFilters();
            var trend_hash = {
                time_trend: true,
                time_trend_conditions: ["doy", "w", "mon", "y", "qtr"],
            };
            jQuery.each(_FD.constants.metrics, function (index, value) {
                var merge_hash = {
                    metric: value,
                    filter: [],
                    date_range: date
                } 
                var bucket_hash = {
                    bucket: true,
                    bucket_conditions: [_FD.constants.bucket_conditions[index]],
                } 
                var bucketparams = jQuery.extend({}, _FD.constants.params, merge_hash, bucket_hash);
                current_params.push(bucketparams);

                var trendparams = jQuery.extend({}, _FD.constants.params, merge_hash, trend_hash);
                current_params.push(trendparams);

            });
            HelpdeskReports.locals.params = current_params.slice();
            _FD.actions.submitReports();
        },
        flushEvents: function () {
            jQuery('#reports_wrapper').off('.perf');
        }
    };
    return {
        init: function () {
            _FD.core = HelpdeskReports.CoreUtil;    
            _FD.constants = jQuery.extend({}, HelpdeskReports.Constants.PerformanceDistribution);
            _FD.bindEvents();
            _FD.core.ATTACH_DEFAULT_FILTER = true;
            _FD.setDefaultValues();
        }
    };
})();