HelpdeskReports.ReportUtil = HelpdeskReports.ReportUtil || {};

HelpdeskReports.ReportUtil.PerformanceDistribution = (function () {
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
            HelpdeskReports.locals.params = current_params;
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
            HelpdeskReports.locals.report_type = _FD.constants.report_type;
            _FD.bindEvents();
            _FD.setDefaultValues();
        }
    };
})();