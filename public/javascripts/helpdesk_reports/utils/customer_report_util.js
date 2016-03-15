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
                    _FD.getTicketListTitle(data);
                    _FD.constructTicketListParams(data);
                }
            });
        },
        getTicketListTitle : function(data){
            var metric = HelpdeskReports.Constants.CustomerReport.metrics[data.metric];
            var value = data.label + " : ";

            if(data.metric == "RESPONSE_VIOLATED" || data.metric == "RESOLUTION_VIOLATED"){
                value += _FD.core.addsuffix(data.y);
            }else{
                value += data.y;
            }
            _FD.core.actions.showTicketList(metric.title,value);
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

            var main_condition = {
                    condition : 'company_id',
                    operator: 'eql',
                    value: data.id
                };

            if(!jQuery.isEmptyObject(main_condition)) {
                list_hash.list_conditions.push(main_condition);
            }

            if (_FD.constants.percentage_metrics.indexOf(data.metric) > -1) {
                //Reset sla the toggle links
                _FD.core.actions.resetSlaLinks();
                var supplement_condition = {
                    condition : _FD.constants.metrics[data.metric].ticket_list_metric,
                    operator : 'is',
                    value : true
                };
                list_hash.list_conditions.push(supplement_condition);
                _FD.core.actions.constructSlaTabs(data.y);
            }else{
                //Hide the sla tabs
                 jQuery(".sla-toggle-tab").addClass('hide');
            }

            var hash = jQuery.extend({},_FD.constants.params, list_hash);
            list_params.push(hash);
            _FD.core.fetchTickets(list_params);
        },
        setDefaultValues: function () {
            var current_params = [];
            var date = _FD.core.setReportFilters();
            jQuery.each(_FD.constants.template_metrics, function (index, value) {
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
        },
        recordAnalytics : function(){
            
            jQuery(document).on("script_loaded", function (ev, data) {
                if( HelpdeskReports.locals.report_type != undefined && HelpdeskReports.locals.report_type == "customer_report"){
                    App.Report.Metrics.push_event("Customer Analysis Report Visited", {});
                }
            });
            
            //Ticket List Exported
             jQuery(document).on("analytics.export_ticket_list", function (ev, data) {
                App.Report.Metrics.push_event("Customer Analysis : Ticket List Exported",{});
             });

            //pdf export
            jQuery(document).on("analytics.export_pdf",function(ev,data){
                App.Report.Metrics.push_event("Customer Analysis : PDF Exported",{});
            });

            //
            jQuery('#reports_wrapper').on('click.helpdesk_reports', "[data-action='reports-submit']", function () {
                App.Report.Metrics.push_event("Customer Analysis Report: Filtered",{ DateRange : HelpdeskReports.locals.date_range });
            });
        }
    };
    return {
        init: function () {
            _FD.core = HelpdeskReports.CoreUtil;    
            _FD.constants = jQuery.extend({}, HelpdeskReports.Constants.CustomerReport);
            _FD.bindEvents();
            _FD.core.ATTACH_DEFAULT_FILTER = false;
            _FD.setDefaultValues();
            _FD.recordAnalytics();
        }
    };
})();