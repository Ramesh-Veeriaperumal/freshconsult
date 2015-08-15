HelpdeskReports.ChartsInitializer = {};

HelpdeskReports.ChartsInitializer.TicketVolume = (function () {
    var _FD = {
        WEEKDAY_MAPPING: {
            'sunday'   : 0,
            'monday'   : 1,
            'tuesday'  : 2,
            'wednesday': 3,
            'thursday' : 4,
            'friday'   : 5,
            'saturday' : 6
        },
        DAY_MAPPING: {
            0 : 'Sundays',
            1 : 'Mondays',
            2 : 'Tuesdays',
            3 : 'Wednesdays',
            4 : 'Thursdays',
            5 : 'Fridays',
            6 : 'Saturdays'
        },
        trend_subtitle: {
            'doy': 'Daily',
            'w'  : 'Weekly',
            'mon': 'Monthly',
            'qtr': 'Quarterly',
            'y'  : 'Yearly'
        },
        week_trend: "week_trend",
        series: ["RECEIVED_TICKETS", "RESOLVED_TICKETS"],
        received_name: "Received",
        resolved_name: "Resolved",
        time_trend_chart: "time_trend",
        day_trend_chart: "day_trend",

        /* Deciding default_trend & trends to be disabled based on selected date range.
           Max data points that will be shown in each trend is 31, i.e 31 days, 31 weeks, 31 months etc.
           Weeks - (31*7 = 217) days, Months - (31*30 = 930) days, Qtr - (31*30*3 = 2790) days, 
           Year - (> 2790) days */
        constraints: {
            31: {
                default_trend: 'doy',
                deactive: []
            },
            217: {
                default_trend: 'w',
                deactive: ["doy"]
            },
            930: {
                default_trend: 'mon',
                deactive: ["doy", "w"]
            },
            2790: {
                default_trend: 'qtr',
                deactive: ["doy", "w", "mon"]
            },
            10000000: {
                default_trend: 'y',
                deactive: ["doy", "w", "mon", "qtr"]
            }
        },
        timeTrend: function (hash) {
            var time_trend_data = [];
            var dateRange = this.dateRangeLimit();
            var current_trend = dateRange.default_trend;
            if (dateRange.deactive.length) {
                jQuery.each(dateRange.deactive, function (i) {
                    jQuery('.chart-trend[data-format="' + dateRange.deactive[i] + '"]').addClass('deactive').attr('title', 'Disabled for this date range');
                });
            }
            this.core_util.trend = current_trend;

            time_trend_data.push({
                name: this.received_name,
                data: _.values(this.hash_received[current_trend])
            }, {
                name: this.resolved_name,
                data: _.values(this.hash_resolved[current_trend])
            });

            var labels = _.keys(this.hash_received[current_trend]);
            var settings = {
                renderTo: this.time_trend_chart + '_chart',
                xAxisLabel: labels,
                chartData: time_trend_data,
                isPDF: false
            }
            var timeBased = new columnChart(settings);
            timeBased.columnGraph();
            jQuery('span[data-format="' + current_trend + '"]').addClass('active');
            jQuery('.trend-subtitle').text(this.trend_subtitle[current_trend]);
        },
        dayTrend: function (hash) {
            var default_day = this.findDefaultDay();
            this.core_util.active_day = this.DAY_MAPPING[default_day];
            var day_trend_data = [];
            var max = this.maxValue(hash);
            day_trend_data.push({
                name: this.received_name,
                data: _.values(this.hash_received[this.week_trend][default_day])
            }, {
                name: this.resolved_name,
                data: _.values(this.hash_resolved[this.week_trend][default_day])
            });
            var settings = {
                renderTo: this.day_trend_chart + '_chart',
                xAxisLabel: _.keys(this.hash_received[this.week_trend][default_day]),
                chartData: day_trend_data,
                isPDF: false,
                yMax: max
            }
            var day_trend = new lineChart(settings);
            day_trend.lineChartGraph();
        },
        miniDayTrends: function (hash) {
            var max = this.maxValue(hash);
            _.each(_.keys(this.WEEKDAY_MAPPING), function (i) {
                var data_array = [];
                var default_day = _FD.findDefaultDay();
                var title = i.toUpperCase();

                data_array.push({
                    name: _FD.received_name,
                    data: _.values(_FD.hash_received[_FD.week_trend][_FD.WEEKDAY_MAPPING[i]])
                }, {
                    name: _FD.resolved_name,
                    data: _.values(_FD.hash_resolved[_FD.week_trend][_FD.WEEKDAY_MAPPING[i]])
                });

                var settings = {
                    renderTo: i + '_chart',
                    chartData: data_array,
                    title: title,
                    isPDF: false,
                    bgcolor: (_FD.WEEKDAY_MAPPING[i] == default_day) ? REPORT_COLORS["plotBG"] : REPORT_COLORS["miniChartBG"],
                    yMax: max,
                    titleColor: (_FD.WEEKDAY_MAPPING[i] == default_day) ? REPORT_COLORS["miniActive"] : REPORT_COLORS["miniAlt"]
                }
                var trend = new miniLineChart(settings);
                trend.miniLineChartGraph();

                if ((_FD.WEEKDAY_MAPPING[i]) == default_day) {
                    jQuery('#' + i + '_chart').addClass('active');
                }
            });

        },
        findDefaultDay: function () {
            var date_range = jQuery('#date_range').val().split('-');
            var diff = (Date.parse(date_range[1]) - Date.parse(date_range[0])) / (36e5 * 24);
            var default_day;

            if (date_range.length > 1 && diff >= 6) {
                default_day = _FD.WEEKDAY_MAPPING['monday'];
            } else {
                default_day = Date.parse(date_range[0]).getDay();
            }

            return default_day;
        },
        dateRangeLimit: function () {
            var date_range = jQuery('#date_range').val().split('-');
            var diff = (Date.parse(date_range[1]) - Date.parse(date_range[0])) / (36e5 * 24);

            switch (true) {

                case (diff < 31):
                    return this.constraints['31'];

                case (diff < 217):
                    return this.constraints['217'];

                case (diff < 930):
                    return this.constraints['930'];

                case (diff < 2790):
                    return this.constraints['2790'];

                case (diff < 10000000):
                    return this.constraints['10000000'];

            }
        },
        maxValue: function (hash) {
            var maxArray = [];
            for (i = 0; i < 7; i++) {
                maxArray.push(_.max(_.values(this.hash_received[this.week_trend][i])));
                maxArray.push(_.max(_.values(this.hash_resolved[this.week_trend][i])));
            }
            return _.max(maxArray);
        },
        bindChartEvents: function () {
            jQuery('.mini-chart').on('click', function () {
                var prev_active = jQuery('.mini-chart.active').attr('id');
                jQuery('.mini-chart').removeClass('active');
                jQuery(this).addClass('active');
                var present = jQuery('.mini-chart.active').attr('id');
                var dow = jQuery(this).closest('.mini-chart').data('value');
                _FD.redrawDayTrend(dow, prev_active, present);
            });
            jQuery('.chart-trend:not(".deactive")').on('click', function () {
                jQuery('.chart-trend').removeClass('active');
                jQuery(this).addClass('active');
                _FD.core_util.trend = jQuery(this).data('format');
                jQuery('.trend-subtitle').text(_FD.trend_subtitle[_FD.core_util.trend]);
                _FD.redrawTimeBased(_FD.core_util.trend);
            });
        },
        redrawDayTrend: function (dow, prev_active, present) {
            this.core_util.active_day = this.DAY_MAPPING[this.WEEKDAY_MAPPING[dow]];
            var chart = jQuery('#day_trend_chart').highcharts();
            for (i = 0; i < this.series.length; i++) {
                chart.series[i].update({
                    data: _.values(this.core_util.chart_hash[this.core_util.metric][this.series[i]][this.week_trend][this.WEEKDAY_MAPPING[dow]])
                }, false);
            }
            chart.redraw(true);

            var prev_active = jQuery('#' + prev_active).highcharts();
            prev_active.chartBackground.css({
                color: REPORT_COLORS['miniChartBG']
            });
            prev_active.title.css({
                color: REPORT_COLORS['miniAlt']
            });

            var present = jQuery('#' + present).highcharts();
            present.chartBackground.css({
                color: REPORT_COLORS['plotBG']
            });
            present.title.css({
                color: REPORT_COLORS['miniActive']
            });
        },
        redrawTimeBased: function (trend) {
            var chart = jQuery('#time_trend_chart').highcharts();
            var labels = _.keys(this.core_util.chart_hash[this.core_util.metric][this.series[0]][trend]);
            chart.xAxis[0].update({
                categories: labels
            }, false);
            for (i = 0; i < this.series.length; i++) {
                chart.series[i].update({
                    data: _.values(this.core_util.chart_hash[this.core_util.metric][this.series[i]][trend])
                }, false);
            }
            chart.zoomOut();
            chart.redraw(true);
        }
    };
    return {
        init: function (hash) {
            _FD.core_util = HelpdeskReports.CoreUtil;
            _FD.hash_received = hash[_FD.core_util.metric][_FD.series[0]];
            _FD.hash_resolved = hash[_FD.core_util.metric][_FD.series[1]];
            _FD.timeTrend(hash);
            _FD.dayTrend(hash);
            _FD.miniDayTrends(hash);
            _FD.bindChartEvents();
        }
    };
})();