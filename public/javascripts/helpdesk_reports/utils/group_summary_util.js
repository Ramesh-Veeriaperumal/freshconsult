HelpdeskReports.ReportUtil = HelpdeskReports.ReportUtil || {};

HelpdeskReports.ReportUtil.GroupSummary = (function () {
    var _FD = {
        bindEvents: function () {
              jQuery('#reports_wrapper').on('click.helpdesk_reports', "[data-action='reports-submit']", function () {
                _FD.actions.submitReports();
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
        setDefaultValues: function () {
            var current_params = [];
            var date = _FD.core.setReportFilters();
            jQuery.each(_FD.constants.metrics, function (index, value) {
                var merge_hash = {
                    metric: value,
                    filter: [],
                    date_range: date
                }
                var param = jQuery.extend({}, _FD.constants.params, merge_hash);
                current_params.push(param);
            });
            HelpdeskReports.locals.params = current_params;
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
                HelpdeskReports.locals.report_type = _FD.constants.report_type;
                _FD.bindEvents();
                _FD.setDefaultValues();
        }
    };
})();