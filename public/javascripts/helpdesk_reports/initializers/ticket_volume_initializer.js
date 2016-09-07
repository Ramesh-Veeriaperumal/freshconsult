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
            1 : 'mondays',
            2 : 'tuesdays',
            3 : 'wednesdays',
            4 : 'thursdays',
            5 : 'fridays',
            6 : 'saturdays',
            0 : 'sundays'
        },
        DAY_MAPPING_LABEL: {
            1 : I18n.t('helpdesk_reports.days_plural.monday'),
            2 : I18n.t('helpdesk_reports.days_plural.tuesday'),
            3 : I18n.t('helpdesk_reports.days_plural.wednesday'),
            4 : I18n.t('helpdesk_reports.days_plural.thursday'),
            5 : I18n.t('helpdesk_reports.days_plural.friday'),
            6 : I18n.t('helpdesk_reports.days_plural.saturday'),
            0 : I18n.t('helpdesk_reports.days_plural.sunday')
        },
        trend_title: {
            'doy': I18n.t('helpdesk_reports.ticket_volume.time_trends_title.doy'),
            'w'  : I18n.t('helpdesk_reports.ticket_volume.time_trends_title.w'),
            'mon': I18n.t('helpdesk_reports.ticket_volume.time_trends_title.mon'),
            'qtr': I18n.t('helpdesk_reports.ticket_volume.time_trends_title.qtr'),
            'y'  : I18n.t('helpdesk_reports.ticket_volume.time_trends_title.y')
        },
        TIME_TRENDS : {
            'doy' : 'day',
            'w'   : 'week',
            'mon' : 'month',
            'qtr' : 'quarter',
            'y'   : 'year'
        },
        week_trend: "week_trend",
        series: ["RECEIVED_TICKETS", "RESOLVED_TICKETS", "ALL_UNRESOLVED_TICKETS"],
        load_analysis_series: ['received', 'resolved', 'unresolved'],
        received_name: I18n.t('helpdesk_reports.chart_title.received'),
        resolved_name: I18n.t('helpdesk_reports.chart_title.resolved'),
        unresolved_name: I18n.t('helpdesk_reports.chart_title.unresolved'),
        total_load: I18n.t('helpdesk_reports.chart_title.total_load'),
        new_received_name: I18n.t('helpdesk_reports.chart_title.new_received'),
        all_resolved_name: I18n.t('helpdesk_reports.chart_title.all_resolved'),
        new_resolved_name: I18n.t('helpdesk_reports.chart_title.new_resolved'),
        all_unresolved_name: I18n.t('helpdesk_reports.chart_title.all_unresolved'),
        new_unresolved_name: I18n.t('helpdesk_reports.chart_title.new_unresolved'),
        time_trend_chart: "time_trend",
        day_trend_chart: "day_trend",
        load_analysis_chart: "load_analysis",

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
            var disabled_date = I18n.t('helpdesk_reports.disabled_date_range');
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
                    jQuery('[data-format="' + dateRange.deactive[i] + '"]').addClass('deactive').attr('title', disabled_date);
                });
            }
            HelpdeskReports.locals.trend = current_trend;

            time_trend_data.push({
                name: this.received_name,
                data: _.values(this.hash_received[current_trend])
            }, {
                name: this.resolved_name,
                data: _.values(this.hash_resolved[current_trend])
            }, {
                name: this.unresolved_name,
                data: _.values(this.hash_unresolved[current_trend])
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
            jQuery("[data-title='trend']").text(this.trend_title[current_trend]);
            _FD.populateAvgAndTotalTicketsLabel();
        },
        loadAnalysisTrend: function(labels, data, div, type, trend, is_pdf){
            //'No data found' needs to be displayed if Data is all zeroes
            if(_.max(data[0].data) == 0 && _.max(data[1].data) == 0){
                var div = [div];
                var msg = I18n.t('helpdesk_reports.no_data_to_display_msg');
                HelpdeskReports.CoreUtil.populateEmptyChart(div, msg);
                return;
            }
            var disabled_date = I18n.t('helpdesk_reports.disabled_date_range');
            var dateRange = this.dateRangeLimit();

            if (dateRange.deactive.length) {
                jQuery.each(dateRange.deactive, function (i) {
                    jQuery('[data-format="' + dateRange.deactive[i] + '"]').addClass('deactive').attr('title', disabled_date);
                });
            }

            var settings = {
                renderTo: div,
                xAxisLabel: labels,
                chartData: data
            }
            var loadAnalysis = new stackedColumnChart(settings, type, trend);
            loadAnalysis.stackedGraph();
            if(!is_pdf){
                this.setTooltipForLegends(this.TIME_TRENDS[trend]);
            }
            
        },
        setTooltipForLegends : function(trend){
            jQuery(jQuery(".info.received")[0]).twipsy({
                html : true,
                placement : "above",
                title : function() { 
                    return I18n.t('helpdesk_reports.chart_title.legend_tooltip.total_load');
            }});

            jQuery(jQuery(".info.received")[1]).twipsy({
                html : true,
                placement : "above",
                title : function() { 
                    return I18n.t('helpdesk_reports.chart_title.legend_tooltip.received', {trend: trend});
            }});

            jQuery(jQuery(".info.resolved")[0]).twipsy({
                html : true,
                placement : "above",
                title : function() { 
                    return I18n.t('helpdesk_reports.chart_title.legend_tooltip.total_load');
              }});
            
            jQuery(jQuery(".info.resolved")[1]).twipsy({
                html : true,
                placement : "above",
                title : function() { 
                    return I18n.t('helpdesk_reports.chart_title.legend_tooltip.all_resolved');
              }});
            
            jQuery(jQuery(".info.resolved")[2]).twipsy({
                html : true,
                placement : "above",
                title : function() { 
                    return I18n.t('helpdesk_reports.chart_title.legend_tooltip.new_resolved', {trend: trend});
              }});
            
            jQuery(jQuery(".info.unresolved")[0]).twipsy({
                html : true,
                placement : "above",
                title : function() { 
                    return I18n.t('helpdesk_reports.chart_title.legend_tooltip.total_load');
              }});


            jQuery(jQuery(".info.unresolved")[1]).twipsy({
                html : true,
                placement : "above",
                title : function() { 
                    return I18n.t('helpdesk_reports.chart_title.legend_tooltip.all_unresolved');
              }});

            jQuery(jQuery(".info.unresolved")[2]).twipsy({
                html : true,
                placement : "above",
                title : function() { 
                    return I18n.t('helpdesk_reports.chart_title.legend_tooltip.new_unresolved', {trend: trend});
              }});

        },  
        getLoadAnalysisData: function(hash, type, trend){
            var data = []
            if(type == _FD.load_analysis_series[0]){
                data = [
                    {
                        name: this.total_load,
                        data: _.values(hash['TOTAL_LOAD'][trend]),
                        pointPadding : 0.2,
                        borderColor: '#F5F5F5',
                        borderWidth: 1
                    },
                    {
                        name: this.new_received_name,
                        data: _.values(hash['RECEIVED_TICKETS'][trend]),
                        pointPadding : 0.2
                    }
                ];
            }
            else if(type == _FD.load_analysis_series[1]){
                data = [
                    {
                        name: this.total_load,
                        data: _.values(hash['TOTAL_LOAD'][trend]),
                        borderColor: '#F5F5F5',
                        borderWidth: 2,
                    },
                    {
                        name: this.all_resolved_name,
                        data: _.values(hash['RESOLVED_TICKETS'][trend]),
                        borderColor : '#7CAF46',
                        borderWidth : 2,
                    },
                    {
                        name: this.new_resolved_name,
                        data: _.values(hash['NEW_RESOLVED_TICKETS'][trend]),
                        borderWidth: 2,
                        borderColor : '#7CAF46'
                    }
                ];
            }
            else{
                data = [
                    {
                        name: this.total_load,
                        data: _.values(hash['TOTAL_LOAD'][trend]),
                        borderColor: '#F5F5F5',
                        borderWidth: 2
                    },
                    {
                        name: this.all_unresolved_name,
                        data: _.values(hash['ALL_UNRESOLVED_TICKETS'][trend]),
                        borderWidth: 2,
                        borderColor : 'rgba(245,166,35,1)'
                    },
                    {
                        name: this.new_unresolved_name,
                        data: _.values(hash['NEW_UNRESOLVED_TICKETS'][trend]),
                        borderColor: 'rgba(245,166,35,1)',
                        borderWidth: 2
                    } 
                ];
            }
            return data;
        },
        getLoadAnalysisLabels: function(hash, type, trend){
            var labels = [];
            if(type == _FD.load_analysis_series[0])
                labels = _.keys(hash['TOTAL_LOAD'][trend]);
            else if(type == _FD.load_analysis_series[1])
                labels = _.keys(hash['RESOLVED_TICKETS'][trend])
            else
                labels = _.keys(hash['ALL_UNRESOLVED_TICKETS'][trend])
            return labels;
        },
        displayLoadAnalysisAvg: function(type, trend){
            var trend_size = _.size(HelpdeskReports.locals.chart_hash['TOTAL_LOAD'][trend]);
            var msg = [];
            msg.push("<span style='color:#666'>Average per " + this.TIME_TRENDS[trend] + " : </span>")
            var total_load = eval(_.values(HelpdeskReports.locals.chart_hash['TOTAL_LOAD'][trend]).join('+'))/trend_size;
            total_load = total_load.round();
            msg.push("<p class='analysis_tooltip'>" + I18n.t('helpdesk_reports.chart_title.tooltip.total_load') + " : " + '<span class="bold">' + total_load + ' ' + (total_load == 0 ? 'ticket' : I18n.t('helpdesk_reports.chart_title.tickets')) + "</span>");
            var preposition = (trend == 'doy' ? 'on' : 'in');
            if(type == 'received'){
                var newly_received = eval(_.values(HelpdeskReports.locals.chart_hash['RECEIVED_TICKETS'][trend]).join('+'))/trend_size;
                newly_received = newly_received.round();
                newly_received = (total_load == 0 ? 0 : ((newly_received/total_load) * 100 || 0).round());
                var carried_over = 100 - newly_received;
                
                msg.push(I18n.t('helpdesk_reports.chart_title.tooltip.carried_over', {count: carried_over}));
                msg.push(I18n.t('helpdesk_reports.chart_title.tooltip.newly_received', {count: newly_received}) + "</p>");
            }
            else if(type == 'resolved'){
                var total_load_resolved = eval(_.values(HelpdeskReports.locals.chart_hash['RESOLVED_TICKETS'][trend]).join('+'))/trend_size;
                total_load_resolved = (total_load == 0 ? 0 : ((total_load_resolved/total_load) * 100 || 0).round());
                var new_received = eval(_.values(HelpdeskReports.locals.chart_hash['RECEIVED_TICKETS'][trend]).join('+'))/trend_size;
                var new_resolved = eval(_.values(HelpdeskReports.locals.chart_hash['NEW_RESOLVED_TICKETS'][trend]).join('+'))/trend_size;
                var newly_received_resolved = ((new_resolved/new_received) * 100 || 0).round();

                msg.push(I18n.t('helpdesk_reports.chart_title.tooltip.total_load_resolved', {count: total_load_resolved}));
                msg.push(I18n.t('helpdesk_reports.chart_title.tooltip.newly_received_resolved', {count: newly_received_resolved}) + "</p>");
            }
            else{
                var total_load_unresolved = eval(_.values(HelpdeskReports.locals.chart_hash['ALL_UNRESOLVED_TICKETS'][trend]).join('+'))/trend_size;
                total_load_unresolved = (total_load == 0 ? 0 : ((total_load_unresolved/total_load) * 100 || 0).round());
                var new_received = eval(_.values(HelpdeskReports.locals.chart_hash['RECEIVED_TICKETS'][trend]).join('+'))/trend_size;
                var new_unresolved = eval(_.values(HelpdeskReports.locals.chart_hash['NEW_UNRESOLVED_TICKETS'][trend]).join('+'))/trend_size;
                var newly_received_unresolved = ((new_unresolved/new_received) * 100 || 0).round();

                msg.push(I18n.t('helpdesk_reports.chart_title.tooltip.total_load_unresolved', {count: total_load_unresolved}));
                msg.push(I18n.t('helpdesk_reports.chart_title.tooltip.newly_received_unresolved', {count: newly_received_unresolved}) + "</p>");
            }
            jQuery('#load_analysis_' + type +'_avg').html(msg.join('<br/>'));
        },
        constructLoadAnalysisTrend: function(hash, type, trend){
            var dateRange = this.dateRangeLimit();
            var current_trend = trend || dateRange.default_trend;
            HelpdeskReports.locals.trend = current_trend;
            var data = _FD.getLoadAnalysisData(hash, type, current_trend);
            var labels = _FD.getLoadAnalysisLabels(hash, type, current_trend);
            _FD.loadAnalysisTrend(labels, data, this.load_analysis_chart + '_' +  type + '_chart', type, current_trend, false);
            _FD.displayLoadAnalysisAvg(type, trend);
        },
        constructPdfLoadAnalysisTrend: function(hash, trend){
            var dateRange = this.dateRangeLimit();
            var current_trend = trend || dateRange.default_trend;
            HelpdeskReports.locals.trend = current_trend;
            for (var i = 0; i < _FD.load_analysis_series.length; i++) {
                var type = _FD.load_analysis_series[i];
                var data = _FD.getLoadAnalysisData(hash, type, current_trend);
                var labels = _FD.getLoadAnalysisLabels(hash, type, current_trend);
                _FD.loadAnalysisTrend(labels, data, this.load_analysis_chart + '_' +  type + '_chart', type, current_trend, true);
            }
        },

        constructDayTrend: function(hash, pdf){
            if(this.hash_received[this.week_trend] == undefined){
                var div = ['day_trend_chart'];
                var msg = I18n.t('helpdesk_reports.no_data_to_display_msg');
                HelpdeskReports.CoreUtil.populateEmptyChart(div, msg);
                jQuery('#mini_chart_wrapper,.busy_period').hide();
                return;
            }
            if(pdf){
                _FD.populateBusiestDayAndHours(pdf);
                _FD.pdfDayTrend(hash);
            }
            else{
                _FD.populateBusiestDayAndHours(pdf);
                _FD.dayTrend(hash);
                _FD.miniDayTrends(hash);
            }
        },
        dayTrend: function (hash) {
            var defaults = this.findDefaultDay();
            var default_day = defaults.active;

            HelpdeskReports.locals.active_day = this.DAY_MAPPING_LABEL[default_day];
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
                xAxis_label: I18n.t('helpdesk_reports.chart_title.hour_of_the_day')
            }
            var day_trend = new lineChart(settings);
            day_trend.lineChartGraph();
            this.setDayTrendAvg(hash);            
        },
        setDayTrendAvg : function(hash){
            var day = HelpdeskReports.locals.active_day;
            var received_hash = hash['RECEIVED_TICKETS']['extra_details']['dow_avg'];
            var resolved_hash = hash['RESOLVED_TICKETS']['extra_details']['dow_avg'];
            var received_avg = 0,resolved_avg = 0;
            switch(day) {
                case 'Mondays' : received_avg = received_hash['Monday_avg'],resolved_avg = resolved_hash['Monday_avg'];break;
                case 'Tuesdays' : received_avg = received_hash['Tuesday_avg'],resolved_avg = resolved_hash['Tuesday_avg'];break;
                case 'Wednesdays' : received_avg = received_hash['Wednesday_avg'],resolved_avg = resolved_hash['Wednesday_avg'];break;
                case 'Thursdays' : received_avg = received_hash['Thursday_avg'],resolved_avg = resolved_hash['Thursday_avg'];break;
                case 'Fridays' : received_avg = received_hash['Friday_avg'],resolved_avg = resolved_hash['Friday_avg'];break;
                case 'Saturdays' : received_avg = received_hash['Saturday_avg'],resolved_avg = resolved_hash['Saturday_avg'];break;
                case 'Sundays' : received_avg = received_hash['Sunday_avg'],resolved_avg = resolved_hash['Sunday_avg'];break;
            }

            //Set the average tooltip
            jQuery('#day_received_avg .received').html(I18n.t('helpdesk_reports.ticket_volume.avg_tickets',{ metric : 'received' , value : received_avg , color : 'rgb(5, 135, 192);' }));
            jQuery('#day_received_avg .resolved').html(I18n.t('helpdesk_reports.ticket_volume.avg_tickets',{ metric : 'resolved' , value : resolved_avg , color : 'rgb(128, 180, 71);' }));
        },
        pdfDayTrend: function (hash) {
            var defaults = this.findDefaultDay();
            var days =  [];
            var chart_id = [];
            _.each(defaults.enabled, function(i){
                days.push(_FD.DAY_MAPPING_LABEL[i]);
                chart_id.push(_FD.DAY_MAPPING[i]);
            });
           
          
            _FD.constructPdfTmpl(days,chart_id);
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
                    xAxis_label: I18n.t('helpdesk_reports.chart_title.hour_of_the_day')
                }
                var day_trend = new lineChart(settings);
                day_trend.lineChartGraph();
            });
        },
        constructPdfTmpl: function (days,chart_id) {
            var tmpl = JST["helpdesk_reports/templates/pdf_day_trend_tmpl"]({
                data: days,
                chart_div_id: chart_id
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
                var title = I18n.t(i,{scope: "helpdesk_reports.days"}).toUpperCase();

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
            if (date_range.length > 1 && diff >6) {

                default_day = _FD.WEEKDAY_MAPPING['monday'];
                doy_active = _.values(_FD.WEEKDAY_MAPPING);

            } else if (date_range.length > 1 && diff <= 6) {
                doy_active = this.defaultDayInsideWeek(date_range);
                disabled_days = _.difference(doy, doy_active);
                default_day = (doy_active.indexOf(1) > -1) ? 1 : doy_active[0];

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
                jQuery("[data-title='trend']").text(_FD.trend_title[HelpdeskReports.locals.trend]);
                _FD.redrawTimeBased(HelpdeskReports.locals.trend);
                //Populate the Total & Average Labels
                _FD.populateAvgAndTotalTicketsLabel();
            });
            jQuery('#reports_wrapper').on('click.helpdesk_reports.vol', "[data-trend='an-trend-type']:not('.deactive')", function () {
                jQuery("[data-trend='an-trend-type']").removeClass('active');
                jQuery(this).addClass('active');
                jQuery("[data-title='an-trend']").text(_FD.trend_title[HelpdeskReports.locals.trend]);
                //_FD.redrawLoadAnalysis(HelpdeskReports.locals.trend);
                _FD.constructLoadAnalysisTrend(HelpdeskReports.locals.chart_hash, jQuery('.load_analysis_nav').find('.active').data('type'), jQuery(this).data('format'));
            });
            //Capturing Tab change in All & New Charts
            jQuery('a[data-toggle="tab"]').on('show.bs.tab', function(e){
                setTimeout(function(){
                    _FD.constructLoadAnalysisTrend(HelpdeskReports.locals.chart_hash, jQuery(e.target).parent().data('type'), HelpdeskReports.locals.trend);
                },0);
            });
            jQuery('#load_analysis_charts').on('mouseover', function(e){
                jQuery('.load_analysis_avg').hide();
            });
            jQuery('#load_analysis_charts').on('mouseout', function(e){
                jQuery('.load_analysis_avg').show();
            });

            jQuery('#day_trend_chart').on('mouseover', function(e){
                jQuery('#day_received_avg').hide();
            });
            jQuery('#day_trend_chart').on('mouseout', function(e){
                jQuery('#day_received_avg').show();
            });
        },
        redrawDayTrend: function (dow, prev_active, present) {
            HelpdeskReports.locals.active_day = this.DAY_MAPPING_LABEL[this.WEEKDAY_MAPPING[dow]];
            this.setDayTrendAvg(HelpdeskReports.locals.chart_hash);
            var chart = jQuery('#day_trend_chart').highcharts();
            //Hack to manage different series length for DayChart & TimeChart (this.series.length - 1)
            for (i = 0; i < this.series.length-1; i++) {
                chart.series[i].update({
                    data: _.values(HelpdeskReports.locals.chart_hash[this.series[i]][this.week_trend][this.WEEKDAY_MAPPING[dow]])
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
        redrawLoadAnalysis: function(trend){
            var charts = ['load_analysis_received_chart', 'load_analysis_resolved_chart', 'load_analysis_unresolved_chart'];
            var labels = [
                _.keys(HelpdeskReports.locals.chart_hash['TOTAL_LOAD'][trend]),
                _.keys(HelpdeskReports.locals.chart_hash['RESOLVED_TICKETS'][trend]),
                _.keys(HelpdeskReports.locals.chart_hash['ALL_UNRESOLVED_TICKETS'][trend]),
            ];
            
            for(i = 0; i< charts.length; i++){
                var chart = jQuery('#'+charts[i]).highcharts();
                chart.xAxis[0].update({
                    categories: labels[i]
                }, false);
                var data = _FD.getLoadAnalysisData(HelpdeskReports.locals.chart_hash, trend);
                chart.series[0].update({data: data.shift()}, false);
                chart.series[1].update({data: data.shift()}, false);
                chart.redraw(true);
            }
        },
        redrawTimeBased: function (trend) {
            var chart = jQuery('#time_trend_chart').highcharts();
            var labels = _.keys(HelpdeskReports.locals.chart_hash[this.series[0]][trend]);
            
            chart.xAxis[0].update({
                categories: labels
            }, false);
            for (i = 0; i < this.series.length; i++) {
                chart.series[i].update({
                    data: _.values(HelpdeskReports.locals.chart_hash[this.series[i]][trend])
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
        generateStatusArrowHtml : function(val, type){
            if(val == "None")
                return '';
            else if(val == 0)
                return '<span class="status-percent"><span class="status-symbol report-arrow no-change left-arrow"></span> <span class="report-arrow no-change right-arrow"></span> 0%</span>'; 
            else{
                if(type == 'received' || type == 'unresolved'){
                    if(val < 0)
                        return '<span class="status-percent"><span class="status-symbol report-arrow down positive"></span> ' + Math.abs(val) +'%</span>';
                    else
                        return '<span class="status-percent"><span class="status-symbol report-arrow up negative"></span> ' + val +'%</span>';
                }
                else{
                    if(val < 0)
                        return '<span class="status-percent"><span class="status-symbol report-arrow down negative"></span> ' + Math.abs(val) +'%</span>';
                    else
                        return '<span class="status-percent"><span class="status-symbol report-arrow up positive"></span> ' + val +'%</span>';
                }
            }
        },
        populateAvgAndTotalTicketsLabel : function(){
            
            var trend = HelpdeskReports.locals.trend;
            var avg_received = jQuery(".stats .avg_received");
            var tot_received = jQuery(".stats .total_received");
            var avg_resolved = jQuery(".stats .avg_resolved");
            var tot_resolved = jQuery(".stats .total_resolved");
            var tot_unresolved = jQuery(".stats .total_unresolved");
            var avg_unresolved = jQuery(".stats .avg_unresolved");

            var core = HelpdeskReports.CoreUtil;
            var limit = core.SHORTEN_LIMIT;
            var shorten_func = core.shortenLargeNumber;
            var tooltip_tmpl = _.template('<span class="tooltip" data-placement="right" data-original-title="<%= value %>" twipsy-content-set="true"><%= truncated_value %></span>');
            
            avg_received.html(_FD.hash_received.extra_details[trend+'_avg'] <= limit ? _FD.hash_received.extra_details[trend+'_avg'] : tooltip_tmpl({ 
                    value : _FD.hash_received.extra_details[trend+'_avg'], 
                    truncated_value : shorten_func(_FD.hash_received.extra_details[trend+'_avg'],1)
            }));
            tot_received.html(_FD.hash_received.extra_details.total <= limit ? _FD.hash_received.extra_details.total : tooltip_tmpl({
                    value : _FD.hash_received.extra_details.total,
                    truncated_value : shorten_func(_FD.hash_received.extra_details.total,1)
            }));
            avg_resolved.html(_FD.hash_resolved.extra_details[trend+'_avg'] <= limit ? _FD.hash_resolved.extra_details[trend+'_avg'] : tooltip_tmpl({
                    value : _FD.hash_resolved.extra_details[trend+'_avg'],
                    truncated_value : shorten_func(_FD.hash_resolved.extra_details[trend+'_avg'],1)
            }));
            tot_resolved.html(_FD.hash_resolved.extra_details.total <= limit ? _FD.hash_resolved.extra_details.total : tooltip_tmpl({
                    value : _FD.hash_resolved.extra_details.total,
                    truncated_value : shorten_func(_FD.hash_resolved.extra_details.total,1)
            }));
            avg_unresolved.html(_FD.hash_unresolved.extra_details[trend+'_avg'] <= limit ? _FD.hash_unresolved.extra_details[trend+'_avg'] : tooltip_tmpl({
                    value : _FD.hash_unresolved.extra_details[trend+'_avg'],
                    truncated_value : shorten_func(_FD.hash_unresolved.extra_details[trend+'_avg'],1)
            }));
            tot_unresolved.html(_FD.hash_unresolved.extra_details.total <= limit ? _FD.hash_unresolved.extra_details.total : tooltip_tmpl({
                    value : _FD.hash_unresolved.extra_details.total,
                    truncated_value : shorten_func(_FD.hash_unresolved.extra_details.total,1)
            }));

            avg_received.append(_FD.generateStatusArrowHtml(_FD.hash_received.extra_details.diff_perc, 'received'));
            tot_received.append(_FD.generateStatusArrowHtml(_FD.hash_received.extra_details.diff_perc, 'received'));
            avg_resolved.append(_FD.generateStatusArrowHtml(_FD.hash_resolved.extra_details.diff_perc, 'resolved'));
            tot_resolved.append(_FD.generateStatusArrowHtml(_FD.hash_resolved.extra_details.diff_perc, 'resolved'));
            avg_unresolved.append(_FD.generateStatusArrowHtml(_FD.hash_unresolved.extra_details.diff_perc, 'unresolved'));
            tot_unresolved.append(_FD.generateStatusArrowHtml(_FD.hash_unresolved.extra_details.diff_perc, 'unresolved'));
        },
        populateBusiestDayAndHours : function(pdf){
            var class_name = pdf ? ".busy_period_pdf " : ".busy_period "
            jQuery(class_name + ".busy_hour_received .value").html(_FD.hash_received.busiest_day_and_hours[1]);
            jQuery(class_name + ".busy_hour_resolved .value").html(_FD.hash_resolved.busiest_day_and_hours[1]);
            jQuery(class_name + ".busy_day_received .value").html(_FD.hash_received.busiest_day_and_hours[0]);
            jQuery(class_name + ".busy_day_resolved .value").html(_FD.hash_resolved.busiest_day_and_hours[0]);
        }
    };
    return {
        init: function (hash, display_day_trend) {
            _FD.hash_received = hash[_FD.series[0]];
            _FD.hash_resolved = hash[_FD.series[1]];
            _FD.hash_unresolved = hash[_FD.series[2]];
            _FD.timeTrend(hash);
            var dateRange = _FD.dateRangeLimit();
            var current_trend = dateRange.default_trend
            current_trend = (current_trend == "doy" && HelpdeskReports.CoreUtil.dateRangeDiff() >= 6) ? 'w' : current_trend;
            _FD.constructLoadAnalysisTrend(hash, _FD.load_analysis_series[0], current_trend);
            _FD.constructDayTrend(hash, false);
            _FD.bindChartEvents();
        },
        pdf: function (hash, print_day_trend) {
            _FD.hash_received = hash[_FD.series[0]];
            _FD.hash_resolved = hash[_FD.series[1]];
            _FD.hash_unresolved = hash[_FD.series[2]];
            _FD.timeTrend(hash);
            var current_trend = HelpdeskReports.locals.trend;
            _FD.constructPdfLoadAnalysisTrend(hash, current_trend);
            _FD.constructDayTrend(hash, true);
        }
    };
})();

