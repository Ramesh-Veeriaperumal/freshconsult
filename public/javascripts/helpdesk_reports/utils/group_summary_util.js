HelpdeskReports.ReportUtil = HelpdeskReports.ReportUtil || {};

HelpdeskReports.ReportUtil.GroupSummary = (function () {
    var _FD = {
        bindEvents: function () {
            jQuery('#reports_wrapper').on('click.helpdesk_reports', "[data-action='reports-submit']", function () {
                _FD.core.flushDataTable();
                _FD.actions.submitReports();
            });

            jQuery('#reports_wrapper').on('click.helpdesk_reports', '[data-table="ticket-data"] td:not(".disable")', function (ev,data) {
                var flag = HelpdeskReports.locals.ticket_list_flag;
                if (flag == false) {
                    HelpdeskReports.locals.ticket_list_flag = true;
                    var el = this;
                    _FD.getTicketListTitle(el);
                    _FD.constructTicketListParams(el);
                }
            });
        },
        getTicketListTitle : function(el){

            var metric_name = jQuery(el).data("metric-name");
            var metric_value = jQuery(el).html();
            var metric_title = jQuery(".summary-table .title [data-metric-title='" + metric_name +"']").html();
            var group_id = jQuery(el).data("group-id");
            var group_name = jQuery("[data-group-id='" + group_id + "']" ).html(); 
            
            var value =   group_name + ' : ' + metric_value;
            _FD.core.actions.showTicketList(metric_title,value);
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
                //Reset sla the toggle links
                _FD.core.actions.resetSlaLinks();
                var supplement_condition = {
                    condition : _FD.constants.ticket_list_metrics[index],
                    operator : 'is',
                    value : false 
                };
                list_hash.list_conditions.push(supplement_condition);
                 _FD.core.actions.constructSlaTabs(jQuery(el).data('order'));
            } else{
                //Hide the sla tabs
                 jQuery(".sla-toggle-tab").addClass('hide');
            }

            var hash = jQuery.extend({}, _FD.constants.params, list_hash);
            list_params.push(hash);

            _FD.core.fetchTickets(list_params);

        },
        setDefaultValues: function () {
            var current_params = [];
            var date = _FD.core.setReportFilters();
            jQuery.each(_FD.constants.template_metrics, function (index, value) {
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
            if (typeof (Storage) !== "undefined" && localStorage.getItem(HelpdeskReports.locals.report_type) !== null) {
                var index = JSON.parse(localStorage.getItem(HelpdeskReports.locals.report_type));
                 HelpdeskReports.SavedReportUtil.applySavedReport(index,false);
            } else {
                 HelpdeskReports.SavedReportUtil.applySavedReport(-1,false);
            }
            _FD.actions.submitReports();
        },
        flushEvents: function () {
            jQuery('#reports_wrapper').off('.group');
        },
        recordAnalytics : function(){

             jQuery(document).on("script_loaded", function (ev, data) {
                 if( HelpdeskReports.locals.report_type != undefined && HelpdeskReports.locals.report_type == "group_summary"){
                     App.Report.Metrics.push_event("Group Summary Report Visited", {});
                 }
             });
            //Ticket List Exported
             jQuery(document).on("analytics.export_ticket_list", function (ev, data) {
                App.Report.Metrics.push_event("Group Summary Report : Ticket List Exported",{ metric : HelpdeskReports.locals.active_metric });
             });

            //pdf export
            jQuery(document).on("analytics.export_pdf",function(ev,data){
                App.Report.Metrics.push_event("Group Summary Report : PDF Exported",{});
            });    
        }
    };
    return {
        init: function () {
                _FD.core = HelpdeskReports.CoreUtil;
                _FD.constants = HelpdeskReports.Constants.GroupSummary;
                _FD.bindEvents();
                _FD.core.ATTACH_DEFAULT_FILTER = true;
                _FD.setDefaultValues();
                _FD.recordAnalytics();
        }
    };
})();