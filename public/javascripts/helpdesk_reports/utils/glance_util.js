HelpdeskReports.ReportUtil = HelpdeskReports.ReportUtil || {};

HelpdeskReports.ReportUtil.Glance = (function () {
    var _FD = {
        bindEvents: function () {
            jQuery('#reports_wrapper').on('click.helpdesk_reports', "[data-action='reports-submit']", function () {
                _FD.actions.submitReports();
            });

            jQuery('#reports_wrapper').on('click.helpdesk_reports', '#glance_sidebar ul li:not(".active"):not(".disabled")', function() {
                _FD.actions.submitActiveMetric(this);
            });

            jQuery('#reports_wrapper').on('change.helpdesk_reports', '#custom_field_group_by select', function() {
                _FD.actions.submitCustomField(this);
            });
        },
        actions: {
            submitReports: function () {
                _FD.setActiveMetric(_FD.constants.default_metric);
                var flag = _FD.core.refreshReports();
                
                if(flag) {
                    _FD.setGroupByInParams();
                    _FD.core.resetAndGenerate();
                }
            },
            submitActiveMetric: function (active) {
                var active_metric = jQuery(active).data('metric');
                _FD.setActiveMetric(active_metric);

                var flag = _FD.core.refreshReports();

                if(flag) {
                    jQuery('#glance_sidebar li').removeClass('active');
                    jQuery('#view_more_wrapper').removeClass('show-all-metrics');
                    jQuery('li[data-metric="'+ active_metric +'"]').addClass('active');
                    jQuery('#glance_chart_wrapper .loading-bar').removeClass('hide');
                    _FD.constructRightPaneParams(active_metric);
                }
            },
            submitCustomField: function (active) {
                var val  = jQuery(active).select2('val');
                HelpdeskReports.locals.active_custom_field = val;
                _FD.constructCustomFieldParams(val);
            }
        },
        setGroupByInParams: function () {
            jQuery.each(HelpdeskReports.locals.params, function (index, value) {
                if (value.bucket == false && value.metric == HelpdeskReports.locals.active_metric) {
                    value.group_by = HelpdeskReports.locals.current_group_by;
                }
            });
        },
        constructRightPaneParams: function (metric) {
            var date = HelpdeskReports.locals.date_range;

            var merge_hash = {
                date_range: date,
                filter: HelpdeskReports.locals.query_hash,
                group_by: HelpdeskReports.locals.current_group_by,
                metric: metric,
                reference: false
            }
            var param = jQuery.extend({}, _FD.constants.params, merge_hash);
            var current_params = [];
            current_params.push(param);
            
            if (_FD.constants.bucket_condition_metrics.indexOf(metric) > -1) {
                var bucket_param = _FD.getBucketConditions(current_params[0],metric);
                current_params.push(bucket_param);
            }
            _FD.renderRightPane(current_params);
        },
        renderRightPane: function (params) {
            HelpdeskReports.CoreUtil.scrollToReports();
            var opts = {
                url: _FD.core.CONST.base_url + HelpdeskReports.locals.report_type + '/fetch_active_metric',
                type: 'POST',
                dataType: 'json',
                contentType: 'application/json',
                data: Browser.stringify(params),
                success: function (data) {
                    HelpdeskReports.ChartsInitializer.Glance.init(data);
                    jQuery('#glance_chart_wrapper .loading-bar').addClass('hide');
                },
                error: function (data) {
                    console.log(data);
                }
            }
            _FD.core.makeAjaxRequest(opts);
        },
        constructCustomFieldParams: function (field) {
            var date = HelpdeskReports.locals.date_range;

            var merge_hash = {
                date_range: date,
                filter: HelpdeskReports.locals.query_hash,
                group_by: [],
                metric: HelpdeskReports.locals.active_metric,
                reference: false
            }
            var param = jQuery.extend({}, _FD.constants.params, merge_hash);
            param.group_by.push(field);

            var current_params = [];
            current_params.push(param);

            _FD.customFieldJSON(current_params);
        },
        customFieldJSON: function (params) {
            var opts = {
                url: _FD.core.CONST.base_url + HelpdeskReports.locals.report_type + '/fetch_active_metric',
                type: 'POST',
                dataType: 'json',
                contentType: 'application/json',
                data: Browser.stringify(params),
                success: function (data) {
                    HelpdeskReports.ChartsInitializer.Glance.customFieldInit(data);
                },
                error: function (data) {
                    console.log(data);
                }
            }
            _FD.core.makeAjaxRequest(opts);
        },
        setDefaultValues: function () {
            var current_params = [];
            var date = _FD.core.setReportFilters();
            var active_metric = _FD.constants.default_metric;
            _FD.setActiveMetric(active_metric);
            jQuery.each(_.keys(_FD.constants.metrics), function (index, value) {
                var merge_hash = {
                    date_range: date,
                    filter: [],
                    group_by: [],
                    metric: value
                }
                var param = jQuery.extend({}, _FD.constants.params, merge_hash);
                current_params.push(param);
            });

            if (_FD.constants.bucket_condition_metrics.indexOf(active_metric) > -1) {
                var bucket_param = _FD.getBucketConditions(current_params[0], active_metric);
                current_params.push(bucket_param);
            }

            HelpdeskReports.locals.params = current_params;
            _FD.actions.submitReports();
        },
        setActiveMetric: function (metric) {
            HelpdeskReports.locals.active_metric = metric;
        },
        getBucketConditions: function (param,metric) {
            var bucket_param = {};
            var bucket_hash = {};
            bucket_hash = {
                metric : metric,
                bucket : true,
                bucket_conditions : _FD.constants.bucket_conditions,
                reference : false,
                group_by : []
            }
            bucket_param = jQuery.extend({},param, bucket_hash);
            return bucket_param;
        }
    };
    return {
        init: function () {
            _FD.core = HelpdeskReports.CoreUtil;
            _FD.constants = jQuery.extend({}, HelpdeskReports.Constants.Glance);
            HelpdeskReports.locals.report_type = _FD.constants.report_type;
            _FD.bindEvents();
            _FD.setDefaultValues();
        }
    };
})();