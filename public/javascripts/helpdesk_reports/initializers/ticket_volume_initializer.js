HelpdeskReports.ChartsInitializer = HelpdeskReports.ChartsInitializer || {};

HelpdeskReports.ChartsInitializer.TicketVolume = (function () {
    var _FD = {
        WEEKDAY_MAPPING: {
            'monday'   : 1,
            'tuesday'  : 2,
            'wednesday': 3,
            'thursday' : 4,
            'friday'   : 5,
            'saturday' : 6,
            'sunday'   : 0
        },
        DAY_MAPPING: {
            1 : 'Mondays',
            2 : 'Tuesdays',
            3 : 'Wednesdays',
            4 : 'Thursdays',
            5 : 'Fridays',
            6 : 'Saturdays',
            0 : 'Sundays'
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
            // If current trend is doy, then making current trend as w!
            if (HelpdeskReports.locals.pdf !== undefined){
                // Explicity set before for PDF rendering
                current_trend = HelpdeskReports.locals.trend
            } else {
                current_trend = (current_trend == "doy" && HelpdeskReports.CoreUtil.dateRangeDiff() >= 6) ? 'w' : current_trend;
            }
            
            
            if (dateRange.deactive.length) {
                jQuery.each(dateRange.deactive, function (i) {
                    jQuery('[data-format="' + dateRange.deactive[i] + '"]').addClass('deactive').attr('title', 'Disabled for this date range');
                });
            }
            HelpdeskReports.locals.trend = current_trend;

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
                chartData: time_trend_data
            }
            var timeBased = new columnChart(settings);
            timeBased.columnGraph();
            jQuery('span[data-format="' + current_trend + '"]').addClass('active');
            jQuery("[data-title='trend']").text(this.trend_subtitle[current_trend]);
            // _FD.populateAvgAndTotalTicketsLabel();
        },
        dayTrend: function (hash) {
            var defaults = this.findDefaultDay();
            var default_day = defaults.active;

            HelpdeskReports.locals.active_day = this.DAY_MAPPING[default_day];
            var day_trend_data = [];
            var max = this.maxValue();
            day_trend_data.push({
                name: this.received_name,
                data: _.values(this.hash_received[this.week_trend][default_day]),
                events: _FD.legendClickEvent(),
            }, {
                name: this.resolved_name,
                data: _.values(this.hash_resolved[this.week_trend][default_day]),
                events: _FD.legendClickEvent(),
            });
            var settings = {
                renderTo: this.day_trend_chart + '_chart',
                xAxisLabel: _.keys(this.hash_received[this.week_trend][default_day]),
                chartData: day_trend_data,
                xAxisType: 'number',
                xAxis_label: 'Hour of the day'
            }
            var day_trend = new lineChart(settings);
            day_trend.lineChartGraph();
        },
        pdfDayTrend: function (hash) {
            var defaults = this.findDefaultDay();
            var days =  [];
            _.each(defaults.enabled, function(i){
                days.push(_FD.DAY_MAPPING[i]);
            });
            _FD.constructPdfTmpl(days);
            _.each(defaults.enabled, function(i){
                var day_trend_data = [];
                var max = _FD.maxValue();
                day_trend_data.push({
                    name: _FD.received_name,
                    data: _.values(_FD.hash_received[_FD.week_trend][i]),
                }, {
                    name: _FD.resolved_name,
                    data: _.values(_FD.hash_resolved[_FD.week_trend][i]),
                });
                var settings = {
                    renderTo: _FD.DAY_MAPPING[i] + '_chart',
                    xAxisLabel: _.keys(_FD.hash_received[_FD.week_trend][i]),
                    chartData: day_trend_data,
                    yMax: max,
                    xAxisType: 'number',
                    xAxis_label: 'Hour of the day'
                }
                var day_trend = new lineChart(settings);
                day_trend.lineChartGraph();
            });
        },
        constructPdfTmpl: function (days) {
            var tmpl = JST["helpdesk_reports/templates/pdf_day_trend_tmpl"]({
                data: days
            });
            jQuery('#pdf_day_trend').html(tmpl);
        },
        legendClickEvent: function () {
            var click_event = {
                show: function () {
                    _FD.toggleMiniChartSeries(this.index, 'show');
                },
                hide: function () {
                    _FD.toggleMiniChartSeries(this.index, 'hide');
                }
            }

            return click_event;
        },
        miniDayTrends: function (hash) {
            var max = this.maxValue();
            var days =  _.keys(this.WEEKDAY_MAPPING);
            var defaults = this.findDefaultDay();
            var default_day = defaults.active;
            var bgcolor, titleColor;
            _FD.constructMiniTrendTmpl(days);

            _.each(days, function (i) {
                var data_array = [];
                var title = i.toUpperCase();

                data_array.push({
                    name: _FD.received_name,
                    data: _.values(_FD.hash_received[_FD.week_trend][_FD.WEEKDAY_MAPPING[i]])
                }, {
                    name: _FD.resolved_name,
                    data: _.values(_FD.hash_resolved[_FD.week_trend][_FD.WEEKDAY_MAPPING[i]])
                });

                if ((_FD.WEEKDAY_MAPPING[i]) == default_day) {

                    bgcolor = REPORT_COLORS["plotBG"];
                    titleColor = REPORT_COLORS["miniActive"]
                    jQuery('#' + i + '_chart').addClass('active');

                } else if (defaults.disabled.indexOf(_FD.WEEKDAY_MAPPING[i]) > -1) {

                    bgcolor = REPORT_COLORS["miniDisable"];
                    titleColor = REPORT_COLORS["miniDisableTitle"]
                    jQuery('#' + i + '_chart').addClass('disable');

                } else {

                    bgcolor = REPORT_COLORS["miniChartBG"];
                    titleColor = REPORT_COLORS["miniAlt"]

                }

                var settings = {
                    renderTo: i + '_chart',
                    chartData: data_array,
                    title: title,
                    bgcolor: bgcolor,
                    yMax: max,
                    titleColor: titleColor
                }

                if (defaults.disabled.indexOf(_FD.WEEKDAY_MAPPING[i]) > -1) {
                    settings.chartData = [];
                }else{
                    settings.chartData = data_array;
                }

                var trend = new miniLineChart(settings);
                trend.miniLineChartGraph();

            });

        },
        constructMiniTrendTmpl: function (days) {
            var tmpl = JST["helpdesk_reports/templates/mini_trend_tmpl"]({
                data: days
            });
            jQuery('#mini_chart_wrapper').html(tmpl);
        },
        findDefaultDay: function () {
            var doy = _.values(_FD.WEEKDAY_MAPPING);
            var date_range = HelpdeskReports.locals.date_range.split('-');
            var diff = (Date.parse(date_range[1]) - Date.parse(date_range[0])) / (36e5 * 24);
            var default_day, default_hash = {}, disabled_days = [], doy_active = [];

            if (date_range.length > 1 && diff >= 6) {

                default_day = _FD.WEEKDAY_MAPPING['monday'];
                doy_active = _.values(_FD.WEEKDAY_MAPPING);

            } else if (date_range.length > 1 && diff < 6) {

                default_day = (doy_active[0] === 0 && doy_active.length > 1) ? doy_active[1] : doy_active[0];
                doy_active = this.defaultDayInsideWeek(date_range);
                disabled_days = _.difference(doy, doy_active);

            } else {
                
                default_day = Date.parse(date_range[0]).getDay();
                doy_active.push(default_day);
                disabled_days = _.difference(doy, doy_active);

            }

            default_hash = {
                active: default_day,
                disabled: disabled_days,
                enabled: doy_active
            }

            return default_hash;
        },
        defaultDayInsideWeek: function (date_range) {
            var end = Date.parse(date_range[1]);
            var daysOfYear = [];
            for (var d = Date.parse(date_range[0]); d <= end; d.setDate(d.getDate() + 1)) {
                daysOfYear.push(d.getDay());
            }
            daysOfYear.sort();

            return daysOfYear;
        },
        dateRangeLimit: function () {
            var date_range = HelpdeskReports.locals.date_range.split('-');
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
        maxValue: function () {
            var maxArray = [];
            for (i = 0; i < 7; i++) {
                maxArray.push(_.max(_.values(this.hash_received[this.week_trend][i])));
                maxArray.push(_.max(_.values(this.hash_resolved[this.week_trend][i])));
            }
            return _.max(maxArray);
        },
        bindChartEvents: function () {
            jQuery("#reports_wrapper").on("click.helpdesk_reports.vol", "[data-name='mini-chart']:not('.disable')", function () {
                var prev_active = jQuery(".active[data-name='mini-chart']").attr('id');
                jQuery("[data-name='mini-chart']").removeClass('active');
                jQuery(this).addClass('active');
                var present = jQuery(".active[data-name='mini-chart']").attr('id');
                var dow = jQuery(this).closest("[data-name='mini-chart']").data('value');
                _FD.redrawDayTrend(dow, prev_active, present);
            });
            jQuery('#reports_wrapper').on('click.helpdesk_reports.vol', "[data-trend='trend-type']:not('.deactive')", function () {
                jQuery("[data-trend='trend-type']").removeClass('active');
                jQuery(this).addClass('active');
                HelpdeskReports.locals.trend = jQuery(this).data('format');
                jQuery("[data-title='trend']").text(_FD.trend_subtitle[HelpdeskReports.locals.trend]);
                _FD.redrawTimeBased(HelpdeskReports.locals.trend);
                //Populate the Total & Average Labels
                _FD.populateAvgAndTotalTicketsLabel();
            });
        },
        redrawDayTrend: function (dow, prev_active, present) {
            HelpdeskReports.locals.active_day = this.DAY_MAPPING[this.WEEKDAY_MAPPING[dow]];
            var chart = jQuery('#day_trend_chart').highcharts();
            for (i = 0; i < this.series.length; i++) {
                chart.series[i].update({
                    data: _.values(HelpdeskReports.locals.chart_hash[HelpdeskReports.locals.metric][this.series[i]][this.week_trend][this.WEEKDAY_MAPPING[dow]])
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
            var labels = _.keys(HelpdeskReports.locals.chart_hash[HelpdeskReports.locals.metric][this.series[0]][trend]);
            chart.xAxis[0].update({
                categories: labels
            }, false);
            for (i = 0; i < this.series.length; i++) {
                chart.series[i].update({
                    data: _.values(HelpdeskReports.locals.chart_hash[HelpdeskReports.locals.metric][this.series[i]][trend])
                }, false);
            }
            chart.redraw(true);
        },
        toggleMiniChartSeries: function (index, toggle) {
            
            var mini = _.keys(_FD.WEEKDAY_MAPPING);

            for (var j = 0; j < mini.length; j++) {

                var mini_chart = jQuery('#' + mini[j] + '_chart' + ':not(.disable)').highcharts();

                if( mini_chart !== undefined ){
                    if(toggle == 'show') {
                    mini_chart.series[index].show();
                    } else if(toggle == 'hide') {
                        mini_chart.series[index].hide();
                    }
                }
                
            };

        },
        populateAvgAndTotalTicketsLabel : function(){
            
            var trend = HelpdeskReports.locals.trend;
            var avg_received = jQuery(".stats .value_average");
            var tot_received = jQuery(".stats .value_total");
            var avg_resolved = jQuery(".stats .value_average");
            var tot_resolved = jQuery(".stats .value_total");
            
            if( trend == 'doy'){
                avg_received.html(_FD.hash_received.doy_avg);
                tot_received.html(_FD.hash_received.doy_total);
                avg_resolved.html(_FD.hash_resolved.doy_avg);
                tot_resolved.html(_FD.hash_resolved.doy_total);
            } else if( trend == 'w') {
                avg_received.html(_FD.hash_received.w_avg);
                tot_received.html(_FD.hash_received.w_total);
                avg_resolved.html(_FD.hash_resolved.w_avg);
                tot_resolved.html(_FD.hash_resolved.w_total);
            } else if( trend == 'mon') {
                avg_received.html(_FD.hash_received.mon_avg);
                tot_received.html(_FD.hash_received.mon_total);
                avg_resolved.html(_FD.hash_resolved.mon_avg);
                tot_resolved.html(_FD.hash_resolved.mon_total);
            } else if( trend == 'qtr') {
                avg_received.html(_FD.hash_received.qtr_avg);
                tot_received.html(_FD.hash_received.qtr_total);
                avg_resolved.html(_FD.hash_resolved.qtr_avg);
                tot_resolved.html(_FD.hash_resolved.qtr_total);
            } else if( trend == 'y') {
                avg_received.html(_FD.hash_received.y_avg);
                tot_received.html(_FD.hash_received.y_total);
                avg_resolved.html(_FD.hash_resolved.y_avg);
                tot_resolved.html(_FD.hash_resolved.y_total);
            }
        }
    };
    return {
        init: function (hash) {
            _FD.hash_received = hash[HelpdeskReports.locals.metric][_FD.series[0]];
            _FD.hash_resolved = hash[HelpdeskReports.locals.metric][_FD.series[1]];
            _FD.timeTrend(hash);
            _FD.dayTrend(hash);
            _FD.miniDayTrends(hash);
            _FD.bindChartEvents();
        },
        pdf: function (hash) {
            _FD.hash_received = hash[HelpdeskReports.locals.metric][_FD.series[0]];
            _FD.hash_resolved = hash[HelpdeskReports.locals.metric][_FD.series[1]];
            _FD.timeTrend(hash);
            _FD.pdfDayTrend(hash);
        }
    };
})();

