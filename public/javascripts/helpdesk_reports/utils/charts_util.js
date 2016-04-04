REPORT_COLORS = {
    plotBG           : "rgba(255,255,255,0.1)",
    title            : "#999999",
    label            : "#191919",
    lineColor        : '#EBEBEB',
    miniChartBG      : '#F1F1F1',
    miniDisable      : '#F9F9F9',
    alternateBG      : "#F4FBFF",
    miniActive       : "#333333",
    miniAlt          : "#555555",
    miniDisableTitle : "#D6D6D6",
    series_colors    : ['#1387C2', '#80B447'],
    borderColor      : 'rgba(0,0,0,0)',
    tooltip_bg       : "rgba(0,0,0,0.6)",
    barChartDummy    : "#F8F8F8",
    barChartReal     : "#5194CC",
    barChartPercent  : "#CFA495",
    gridLineColor    : "#f0f0f0",
    bucket_series    : ['#6FB5EC', '#FFCA7E']
}

COLUMN_SERIES = {
    'Received': "RECEIVED_TICKETS",
    'Resolved': "RESOLVED_TICKETS"
}


MONTHS = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec']

I18N_QTR_NAMES = I18n.t('helpdesk_reports.abbr_qtr') 
I18N_MONTHS = I18n.t('helpdesk_reports.abbr_month_names')


// TODO: Namespace it to helpdesk reports
function helpdeskReports(opts) {
    Highcharts.dateFormats = {
        W: function (timestamp) {
            var start_date    = new Date(parseInt(HelpdeskReports.locals.startTimestamp));
            var selected_date = new Date(timestamp);
            var current_date  = selected_date > start_date ? selected_date : start_date;
            return Highcharts.dateFormat('%e %b',current_date);
        },
        qtr: function (timestamp) {
            var current_date = new Date(timestamp),
                point = Math.floor(current_date.getMonth() / 3);
            return I18N_QTR_NAMES[point];
        }
    };

    this.options = {
        lang: {
            shortMonths: I18n.t('helpdesk_reports.abbr_month_names'),
        },
        credits: {
            enabled: false
        },
        exporting: {
            enabled: false
        },
        chart: {
            style: {
                fontFamily: '"Helvetica Neue", Helvetica, Arial'
            },
            color: REPORT_COLORS['label']
        },
        tooltip: {
            xDateFormat: '%d/%m/%Y %H:%M:%S'
        },
        title: {
            text: ''
        },
        isPDF: false
    };
    this.options = jQuery.extend(this.options, opts);
}

helpdeskReports.prototype = {
    updateDefaultCharts: function () {
        Highcharts.setOptions(this.options);
    },
    columnChartTooltip: function () {
        var y = (this.point.y).toFixed(0);
        if (this.point.series.index == 0) {
            return '<div class="tooltip"> <p style="margin:0;color:#63b3f5;font-size: 13px;font-weight: 500">' + I18n.t('helpdesk_reports.chart_title.tooltip.total_tickets_received',{count: y}) + '</p></div>';
        } else {
            return '<div class="tooltip"> <p style="margin:0;color:#64b740;font-size: 13px;font-weight: 500">' + I18n.t('helpdesk_reports.chart_title.tooltip.total_tickets_resolved',{count: y}) + '</p></div>';
        }
    },
    perfXAxisTrendLabel: function(timestamp){
        var trend = HelpdeskReports.locals.trend;
         switch (trend) {
            case 'doy':
                return Highcharts.dateFormat('%e %b , %Y', timestamp);
            case 'w':
                return Highcharts.dateFormat('%W , %Y', timestamp);
            case 'mon':
                return Highcharts.dateFormat('%b , %Y', timestamp);
            case 'qtr':
                return Highcharts.dateFormat('%qtr , %Y', timestamp);
            case 'y':
                return Highcharts.dateFormat('%Y', timestamp);
        }  
    },
    ticketListTrendLabel: function(category) {
        return helpdeskReports.prototype.xAxisTrendLabel(true,category);
    },
    xAxisTrendLabel: function(is_column_chart_clicked,clicked_category) {  
       
        var trend = HelpdeskReports.locals.trend;
        var value = clicked_category || this.value;

        //TODO: 
        if (typeof value == 'string') {
            switch (trend) {

            case 'doy':
                var chart_label = value.split(/[,\s]/);
                var label = '';
                month_index = _.indexOf(MONTHS,chart_label[1].trim());
                month = I18N_MONTHS[month_index];
                if (is_column_chart_clicked){
                    label = I18n.t('helpdesk_reports.ticket_volume.labels.day_month_year',{day: chart_label[0], month: month, year: chart_label[3] });
                }
                else{
                    label = I18n.t('helpdesk_reports.ticket_volume.labels.day_month',{day: chart_label[0], month: month});
                }
                return label;

            case 'w':
                
                    var chart_label_array = value.split('-');
                    var label_day = [];
                    var label_month = [];
                    var label_year = [];
                    var label = '';
                    for(i=0; i< chart_label_array.length;i++)
                    {
                        var chart_label = chart_label_array[i].trim().split(/[,\s]/) 
                        label_day[i] = chart_label[0];
                        label_month[i] = I18N_MONTHS[_.indexOf(MONTHS,chart_label[1].trim())];
                        label_year[i] = chart_label[3];
                    }
                    if (is_column_chart_clicked)
                    {
                        label = I18n.t('helpdesk_reports.ticket_volume.labels.week_with_year',{start_day: label_day[0], start_month: label_month[0], start_year: label_year[0], end_day: label_day[1], end_month: label_month[1], end_year: label_year[1]});
                    }
                    else
                    {
                        label = I18n.t('helpdesk_reports.ticket_volume.labels.day_month',{day: label_day[0], month: label_month[0]});
                    }
                    return label;
                    
                
            case 'mon':
                
                var d = Date.parse(value);
                var label_split = value.split(",");
                var label = '';
                var month = I18N_MONTHS[d.getMonth()];
                if (d.getMonth() == 0 || this.isFirst || is_column_chart_clicked) {
                    label = I18n.t('helpdesk_reports.ticket_volume.labels.month_year',{month: month, year: label_split[1] });
                } else { 
                    label = I18n.t('helpdesk_reports.ticket_volume.labels.month',{month: month});
                }   
                return label;

            case 'qtr':

                var label_split = value.split(/[-,]/);
                var start_month = I18N_MONTHS[_.indexOf(MONTHS,label_split[0].trim())];
                var end_month = I18N_MONTHS[_.indexOf(MONTHS,label_split[1].trim())];
                var d = Date.parse(label_split[0].trim());
                var label = '';
                if  (d.getMonth() == 0 || this.isFirst || (is_column_chart_clicked)) {
                    label = I18n.t('helpdesk_reports.ticket_volume.labels.qtr_year',{start_month: start_month, end_month: end_month, year: label_split[2]});  
                } else {
                    label = I18n.t('helpdesk_reports.ticket_volume.labels.qtr',{start_month: start_month, end_month: end_month});
                }
                return label;
            case 'y':
               return value;
            }
        }
    },
    lineLabelFormatter: function() {
        if ( this.isFirst ) { return ''; }
        return this.value;
    },
    columnChartDataLabels: function () {
        if (this.y > 0) return this.y;
    },
    lineChartTooltip: function () {
        var active_day = HelpdeskReports.locals.active_day;
        var x = "<div class='tooltip'>";
        jQuery.each(this.points, function (i, point) {
            var y = (point.y) % 1 === 0 ? (this.y) : (this.point.y).toFixed(2);
            var metric = I18n.t(point.series.name.toLowerCase(),{scope: "helpdesk_reports", defaultValue: point.series.name.toLowerCase()});
            x += '<p style="margin:0;display:inline-block;color:' + point.series.color + '">' + I18n.t('helpdesk_reports.chart_title.tooltip.avg_tickets',{metric: metric,value: y}) + '</p><br/>';
        });
        if(active_day){
            x += "<p>(" + I18n.t('helpdesk_reports.chart_title.tooltip.avg_of_all',{day: active_day}) + ")</p>"; 
        }
        x += "</div>";
        return x;
    },
    hrPerformancelineTooltip: function () {
        return helpdeskReports.prototype.performancelineTooltip(this,"Hours");
    },
    minPerformancelineTooltip: function () {
        return helpdeskReports.prototype.performancelineTooltip(this,"Mins");
    },
    performancelineTooltip: function(obj, plot_type){
        var _this = obj;
        var x = "<div class='tooltip'>";
        x += '<p style="margin:0;display:inline-block;color:ffffff">' + this.perfXAxisTrendLabel(_this.x) + '</p></br>'; 
        
        jQuery.each(_this.points, function (i, point) {
            var y     = (point.y) % 1 === 0 ? (_this.y) : (point.y);
            var value = plot_type === "Hours" ? (y * 3600): (y * 60); //Converting it into seconds
            x += '<p style="margin:0;display:inline-block;color:' + point.series.color + '">' + point.series.name + ' : ' + helpdeskReports.prototype.timeLabelFormatter(value) + '</p><br/>';
        });
        x += "</div>";
        return x;
    },
    barChartSLATooltip: function () {
        var series = this.series.index;
        var fp,sp;
        if (series == 1) {
            fp = this.y;
            return '<div class="tooltip"><p style="margin:0;color:#63b3f5;">' + I18n.t('helpdesk_reports.chart_title.tooltip.compliant',{percent_of_tickets: fp})+'% </p></div>'
        } else {
            var index = this.series.data.indexOf(this.point);
            var point = parseInt(100 - this.series.chart.series[1].data[index].y);
            return '<div class="tooltip"><p style="margin:0;color:#f48f6c;">' + I18n.t('helpdesk_reports.chart_title.tooltip.violated',{percent_of_tickets: point}) + '%</p></div>';
        }
    },
    performanceDistributionBarChartTooltip : function(){
        var value = this.points[1].y;
        if (value == 0 ) return false;
        var dataSum = this.points[1].series.options.total;
        var pcnt = (value / dataSum) * 100;
        var color = this.points[1].series.color;
        var tooltip_name = this.points[1].series.options.tooltip_name;
        return '<div class="tooltip"><p style="margin:0;color:'+color+';"> ' + this.points[1].x + ' : '+ Highcharts.numberFormat(pcnt) + '% '+ I18n.t('helpdesk_reports.chart_title.tickets')+'</p></div>';
    },
    barChartTooltip: function(){
        var value = this.points[1].y;
        if (value == 0 ) return false;
        var dataSum = this.points[1].series.options.total;
        var pcnt = (value / dataSum) * 100;
        var color = this.points[1].series.color;
        return '<div class="tooltip"><p style="margin:0;color:'+color+';"> ' + this.points[1].x + ' : '+ Highcharts.numberFormat(pcnt) + '%</p></div>'
    },
    barChartSeriesTooltip: function () {
        if (this.point.series.index == 0) {
            return '<div class="tooltip"><p style="margin:0;color:#63b3f5;">'+ I18n.t('helpdesk_reports.chart_title.tooltip.tickets_with_agent_responses',{ticket_count: this.y, count: this.x}) + '<br/></p></div>';
        } else {
            return '<div class="tooltip"><p style="margin:0;color:#ffe397;">'+ I18n.t('helpdesk_reports.chart_title.tooltip.tickets_with_customer_responses',{ticket_count: this.y, count: this.x}) + '<br/></p></div>';
        }
    },
    numberLabelFormatter: function(number){
        var num = this.value || number;
        if (num == 0 || typeof num === 'undefined' ) 
            return '0';
        return HelpdeskReports.CoreUtil.shortenLargeNumber(num,1);
    },
    timeLabelFormatter: function (secs) {
        var total_seconds = this.value || secs;
        if (total_seconds == 0 || typeof total_seconds === 'undefined' ) 
            return '0m 0s';
        return HelpdeskReports.CoreUtil.timeMetricConversion(total_seconds);
    },
    barLabelFormatter: function () {
        var s = this.value;
        var r = "",str="",p;
        var lastAppended = 0;
        var lastSpace = -1;
        var breakCount = 0;
        for (var i = 0; i < s.length; i++) {
            if (s.charAt(i) == ' ') lastSpace = i;
            if (i - lastAppended > 8) {
                if (lastSpace == -1) 
                    lastSpace = i;
                r += s.substring(lastAppended, lastSpace);
                lastAppended = lastSpace;
                lastSpace = -1;   
                r += "<br>";
                breakCount++;
            }
            if (breakCount==2) break;
        }
        r   += s.substring(lastAppended, s.length);//appending last words..
        p    = r.split('<br>', 2).join('<br>').length;//Displaying Only 2 lines
        str  = r.substring(0,p);
        return r.substring(p).length > 0 ? '<span title="'+s+'">'+str+'...</span>' : str; //Appending '...'' if skipping more words...
    }
}


function columnChart(opts) {
    helpdeskReports.call(this, {
        chart: {
            renderTo: opts['renderTo'],
            type: 'column',
            borderColor: REPORT_COLORS['borderColor'],
            plotBackgroundColor: REPORT_COLORS['plotBG'],
            backgroundColor: REPORT_COLORS['plotBG'],
            height: 375
        },
        title: {
            text: (typeof opts['title'] === 'undefined') ? '' : opts['title'],
            style: {
                fontSize: '13px'
            }
        },
        xAxis: {
            categories: opts['xAxisLabel'],
            labels: {
                style: {
                    fontSize: '12px',
                    color: REPORT_COLORS['label']
                },
                formatter: this.xAxisTrendLabel
            },
            tickLength: 0,
            minorTickLength: 0,
            lineColor: REPORT_COLORS['lineColor'],
        },
        yAxis: {
            min: 0,
            allowDecimals: false,
            title: {
                text: (typeof opts['yAxis_label'] === 'undefined') ? I18n.t('helpdesk_reports.chart_title.no_of_tickets') : opts['yAxis_label'],
                align: 'middle',
                style: {
                    fontSize: '12px',
                    color: REPORT_COLORS['title']
                },
                margin: 25
            },
            labels: {
                overflow: 'justify',
                style: {
                    fontSize: '12px',
                    color: REPORT_COLORS['label']
                }
            },
            alternateGridColor: REPORT_COLORS['alternateBG'],
            gridLineWidth: 0,
            minorGridLineWidth: 0,
            lineColor: REPORT_COLORS['lineColor'],
            lineWidth: 1,
            startOnTick: true
        },
        colors: REPORT_COLORS["series_colors"],
        plotOptions: {
            column: {
                borderWidth: 0,
                pointPadding: 0
            },
            series: {
                shadow: false,
                groupPadding: 0.3,
                cursor: 'pointer',
                point: {
                    events: {
                        click: function () {
                            trigger_event("timetrend_point_click.helpdesk_reports", {
                                sub_metric: COLUMN_SERIES[this.series.name],
                                value : (this.y).toFixed(0),
                                date: helpdeskReports.prototype.ticketListTrendLabel(this.category),

                            });
                        }
                    }
                },
                animation: {
                    duration: 1000,
                    easing: 'easeInOutQuart'
                }
            }
        },
        tooltip: {
            formatter: this.columnChartTooltip,
            useHTML: true,
            backgroundColor: REPORT_COLORS['tooltip_bg'],
            borderColor: 'none',
            shadow: false,
            style: {
                padding: 0
            },
            hideDelay: 50
        },
        series: opts['chartData'],
        legend: {
            borderWidth: 0,
            itemStyle: {
                bottom: 0,
                top: 'auto',
                fontWeight: 'normal'
            },
            verticalAlign: 'bottom',
            itemDistance: 50
        }
    });
}

columnChart.prototype = new helpdeskReports;
columnChart.prototype.updateDefaultCharts();
columnChart.constructor = columnChart;

columnChart.prototype.columnGraph = function () {
    var chart = new Highcharts.Chart(this.options);
}


function lineChart(opts) {
    helpdeskReports.call(this, {
        chart: {
            renderTo: opts['renderTo'],
            type: 'line',
            borderColor: REPORT_COLORS['borderColor'],
            plotBackgroundColor: REPORT_COLORS['plotBG'],
            backgroundColor: REPORT_COLORS['plotBG'],
            height: 300,
            borderWidth: 1,
            paddingTop: 100
        },
        title: {
            text: (typeof opts['title'] === 'undefined') ? '' : opts['title'],
            style: {
                fontSize: '13px'
            }
        },
        xAxis: [{
            categories: opts['xAxisLabel'],
            labels: {
                style: {
                    fontSize: '12px',
                    color: REPORT_COLORS['label']
                },
                formatter: opts['xAxisType'] == 'trend' ? this.xAxisTrendLabel : null,
                useHTML : true,
            },
            title: {
                text: (typeof opts['xAxis_label'] === 'undefined') ? null : opts['xAxis_label'],
                align: 'middle',
                style: {
                    fontSize: '13px',
                    color: REPORT_COLORS['title']
                },
                margin: 25
            },
            tickLength: 0,
            minorTickLength: 0,
            lineColor: REPORT_COLORS['lineColor'],
            min: 0.5,
            startOnTick: false
        }, {
            title: {
                text: null
            },
            lineColor: REPORT_COLORS['lineColor'],
            lineWidth: 1,
            opposite: true
        }],
        yAxis: [{
            min: 0,
            allowDecimals: false,
            max: (typeof opts['yMax'] !== 'undefined') ? opts['yMax'] : null,
            title: {
                text: (typeof opts['yAxis_label'] === 'undefined') ? I18n.t('helpdesk_reports.chart_title.avg_no_of_tickets') : opts['yAxis_label'],
                align: 'middle',
                style: {
                    fontSize: '13px',
                    color: REPORT_COLORS['title']
                },
                margin: 25
            },
            labels: {
                overflow: 'justify',
                style: {
                    fontSize: '12px',
                    color: REPORT_COLORS['label']
                },
                formatter: this.lineLabelFormatter
            },
            gridLineWidth: 1,
            gridLineColor: REPORT_COLORS['gridLineColor'],
            gridLineDashStyle: 'dot',
            minorGridLineWidth: 0,
            lineColor: REPORT_COLORS['lineColor'],
            lineWidth: 1,
            startOnTick: true
        }, {
            min: 0,
            title: {
                text: null
            },
            lineColor: REPORT_COLORS['lineColor'],
            lineWidth: 1,
            opposite: true
        }],
        colors: REPORT_COLORS["series_colors"],
        plotOptions: {
            series: {
                shadow: false,
                lineWidth: 3,
                animation: {
                    duration: 1000,
                    easing: 'easeInOutQuart'
                },
                marker: {
                    enabled: true,
                    radius: 1
                }
            },
            line: {
                marker: {
                    enabled: true,
                    radius: 1
                }
            }
        },
        tooltip: {
            formatter: this.lineChartTooltip,
            crosshairs: {
                color: 'gray',
                dashStyle: 'solid',
                width: 1
            },
            shared: true,
            useHTML: true,
            backgroundColor: REPORT_COLORS['tooltip_bg'],
            borderColor: 'none',
            shadow: false,
            style: {
                padding: 0
            },
            hideDelay: 50
        },
        series: opts['chartData'],
        legend: {
            borderWidth: 0,
            itemStyle: {
                bottom: 0,
                top: 'auto',
                fontWeight: 'normal'
            },
            verticalAlign: 'bottom',
            floating: false,
            itemDistance: 50
        }
    });
}
lineChart.prototype = new helpdeskReports;
lineChart.prototype.updateDefaultCharts();
lineChart.constructor = lineChart;

lineChart.prototype.lineChartGraph = function () {
    var chart = new Highcharts.Chart(this.options);
}


function miniLineChart(opts) {
    helpdeskReports.call(this, {
        chart: {
            renderTo: opts['renderTo'],
            type: 'line',
            height: 80,
            backgroundColor: (typeof opts['bgcolor'] === 'undefined') ? REPORT_COLORS["miniChartBG"] : opts['bgcolor'],
            plotBackgroundColor: REPORT_COLORS['plotBG'],
            borderRadius: 0,
            margin: [25, 10, 10, 10],
            spacingTop: 10,
            spacingBottom: 10,
            spacingLeft: 10,
            spacingRight: 10
        },
        title: {
            text: (typeof opts['title'] === 'undefined') ? '' : opts['title'],
            style: {
                fontSize: '14px',
                color: (typeof opts['titleColor'] === 'undefined') ? REPORT_COLORS['altTitle'] : opts['titleColor']
            },
            color: REPORT_COLORS['label'],
            align: 'left'
        },
        xAxis: {
            labels: {
                enabled: false
            },
            minorTickLength: 0,
            tickLength: 0,
            lineWidth: 0
        },
        yAxis: {
            min: 0,
            max: (typeof opts['yMax'] !== 'undefined') ? opts['yMax'] : null,
            title: {
                text: null,
            },
            labels: {
                enabled: false
            },
            gridLineWidth: 0,
            minorGridLineWidth: 0,
            minPadding: 0,
            maxPadding: 0
        },
        colors: REPORT_COLORS["series_colors"],
        plotOptions: {
            series: {
                shadow: false,
                enableMouseTracking: false,
                animation: {
                    duration: 1000,
                    easing: 'easeInOutQuart'
                }
            },
            line: {
                marker: {
                    enabled: false
                }
            }
        },
        tooltip: {
            enabled: false
        },
        series: opts['chartData'],
        legend: {
            enabled: false
        }
    });
}
miniLineChart.prototype = new helpdeskReports;
miniLineChart.prototype.updateDefaultCharts();
miniLineChart.constructor = miniLineChart;

miniLineChart.prototype.miniLineChartGraph = function () {
    var chart = new Highcharts.Chart(this.options);
}


function barChart(opts) {
    helpdeskReports.call(this, {
        chart: {
            renderTo: opts['renderTo'],
            type: 'bar',
            plotBackgroundColor: REPORT_COLORS['plotBG'],
            backgroundColor: REPORT_COLORS['plotBG'],
            borderRadius: 0,
            height: opts['height']
        },
        title: {
            text: (typeof opts['title'] === 'undefined') ? '' : opts['title'],
            style: {
                fontSize: '14px',
            }
        },
        xAxis: [{
            categories: opts['xAxisLabel'],
            labels: {
                style: {
                    width: '65px',
                    'min-width': '65px',
                    fontSize: '12px',
                    textAlign: 'right',
                },
                formatter: opts['performanceDistTooltip'] ? null : this.barLabelFormatter,
                useHTML: true
            },
            title:{
              text: null
            },
            minorTickLength: 0,
            tickLength: 0,
            lineWidth: 0,
            minPadding: 0,
            maxPadding: 0
        },{
            opposite: true,
            linkedTo: 0,
            categories: opts['dataLabels'],
            title:{
              text: null
            },
            labels: {
                style: {
                    fontSize: '12px',
                    fontWeight: 600
                },
                useHTML : true,
                formatter: opts['timeFormat'] == true ? this.timeLabelFormatter : ( opts['suffix'] === undefined ? this.numberLabelFormatter : null),
                format: opts['suffix'] === undefined ? null : opts['suffix']
            },
            minorTickLength: 0,
            tickLength: 0,
            lineWidth: 0,
            minPadding: 0,
            maxPadding: 0
        }],
        yAxis: {
            min: 0,
            title: {
                enabled: false
            },
            labels: {
                enabled: false
            },
            max: opts['yAxisMaxValue'] === undefined ? null : opts['yAxisMaxValue'],
            gridLineWidth: 0,
            minorGridLineWidth: 0,
            minPadding: 0,
            maxPadding: 0
        },
        plotOptions: {
            bar: {
                pointWidth: 12,
                grouping: false,
                minPointLength: opts['minPoint'] === undefined ? 0 : 2
            },
        },
        tooltip: {
            useHTML: true,
            shared: opts['sharedTooltip'],
            formatter: opts['sharedTooltip'] == true ? ( opts['performanceDistTooltip'] ? this.performanceDistributionBarChartTooltip : this.barChartTooltip) : this.barChartSLATooltip,
            followPointer: true,
            enabled: opts['enableTooltip'] == true ? true : false,
            backgroundColor: REPORT_COLORS['tooltip_bg'],
            borderColor: 'none',
            shadow: false,
            style: {
                padding: 0
            },
            hideDelay: 50
        },
        series: opts['chartData'],
        legend: {
            enabled: false
        }
    });
}
barChart.prototype = new helpdeskReports;
barChart.prototype.updateDefaultCharts();
barChart.constructor = barChart;

barChart.prototype.barChartGraph = function () {
    var chart = new Highcharts.Chart(this.options);
}


function barChartMultipleSeries(opts) {
    helpdeskReports.call(this, {
        chart: {
            renderTo: opts['renderTo'],
            type: 'bar',
            plotBackgroundColor: REPORT_COLORS['plotBG'],
            backgroundColor: REPORT_COLORS['plotBG'],
            borderRadius: 0,
            height: opts['height']
        },
        title: {
            text: (typeof opts['title'] === 'undefined') ? '' : opts['title'],
            style: {
                fontSize: '14px',
            }
        },
        xAxis: {
            categories: opts['xAxisLabel'],
            labels: {
                style: {
                    width: '20px',
                    'min-width': '20px',
                    fontSize: '12px',
                },
                useHTML : true
            },
            title: {
                text: (typeof opts['xAxis_title'] === 'undefined') ? null : opts['xAxis_title'],
                align: 'middle',
                style: {
                    fontSize: '13px',
                    color: REPORT_COLORS['title']
                },
                margin: 25
            },
            minorTickLength: 0,
            tickLength: 0,
            lineWidth: 1,
            lineColor: REPORT_COLORS['gridLineColor'],
            gridLineWidth: 0,
        },
        yAxis: {
            min: 0,
            title: {
                text: (typeof opts['yAxis_title'] === 'undefined') ? null : opts['yAxis_title'],
                align: 'middle',
                style: {
                    fontSize: '13px',
                    color: REPORT_COLORS['title']
                },
                margin: 15
            },
            allowDecimals: false,
            gridLineWidth: 0,
            lineWidth: 1,
            lineColor: REPORT_COLORS['gridLineColor'],
        },
        colors: REPORT_COLORS["bucket_series"],
        plotOptions: {
            bar: {
                borderWidth: 0,
                pointPadding: 0,
                pointWidth: opts['pointWidth'] === undefined ? null : opts['pointWidth']
            },
            series: {
                shadow: false,
                groupPadding: 0.3,
                animation: {
                    duration: 1000,
                    easing: 'easeInOutQuart'
                },
            }
        },
        tooltip: {
            useHTML: true,
            formatter: this.barChartSeriesTooltip,
            backgroundColor: REPORT_COLORS['tooltip_bg'],
            borderColor: 'none',
            shadow: false,
            followPointer: true,
            style: {
                padding: 0
            },
            hideDelay: 50
        },
        series: opts['chartData'],
        legend: {
            enabled : opts['legend'] == true ? true : false, 
            borderWidth: 0,
            itemStyle: {
                bottom: 0,
                top: 'auto',
                fontWeight: 'normal',
                cursor: 'pointer'
            },
            verticalAlign: 'bottom',
            symbolPadding: 10,
            symbolWidth: 10,
            symbolHeight: 10,
            x: 25,
        }
    });
}
barChartMultipleSeries.prototype = new helpdeskReports;
barChartMultipleSeries.prototype.updateDefaultCharts();
barChartMultipleSeries.constructor = barChartMultipleSeries;

barChartMultipleSeries.prototype.barChartSeriesGraph = function () {
    var chart = new Highcharts.Chart(this.options);
}


function perfLineChart(opts) {
    helpdeskReports.call(this, {
        chart: {
            renderTo: opts['renderTo'],
            type: 'line',
            borderColor: REPORT_COLORS['borderColor'],
            plotBackgroundColor: REPORT_COLORS['plotBG'],
            backgroundColor: REPORT_COLORS['plotBG'],
            height: 300,
            borderWidth: 1,
            paddingTop: 100,
            marginRight: 40
        },
        title: {
            text: (typeof opts['title'] === 'undefined') ? '' : opts['title'],
            style: {
                fontSize: '13px'
            }
        },
        xAxis: [{
            type: 'datetime',
            labels: {
                style: {
                    fontSize: '12px',
                    color: REPORT_COLORS['label']
                },
                format: (typeof opts['xAxisFormat'] === 'undefined') ? null : opts['xAxisFormat'],
                step: (typeof opts['xAxisStepValue'] === 'undefined') ? null : opts['xAxisStepValue'],
                useHTML: true,
                showLastLabel: true
            },
            tickInterval: (typeof opts['xAxisTickInterval'] === 'undefined') ? null :  opts['xAxisTickInterval'],
            min: (typeof opts['start_date'] === 'undefined') ? null : opts['start_date'],
            max: (typeof opts['end_date'] === 'undefined') ? null : opts['end_date'],
                
            title: {
                text: (typeof opts['xAxis_label'] === 'undefined') ? null : opts['xAxis_label'],
                align: 'middle',
                style: {
                    fontSize: '13px',
                    color: REPORT_COLORS['title']
                },
                margin: 25
            },
            showLastLabel: true,
            tickLength: 0,
            minorTickLength: 0,
            lineColor: REPORT_COLORS['lineColor'],
            minPadding: 0,
            maxPadding: 0,
            startOnTick: true,
            endOnTick: true,
        }, {
            title: {
                text: null
            },
            lineColor: REPORT_COLORS['lineColor'],
            lineWidth: 1,
            opposite: true
        }],
        yAxis: [{
            min: 0,
            allowDecimals: false,
            max: (typeof opts['yMax'] !== 'undefined') ? opts['yMax'] : null,
            title: {
                text: (typeof opts['yAxis_label'] === 'undefined') ? null : opts['yAxis_label'],
                align: 'middle',
                style: {
                    fontSize: '13px',
                    color: REPORT_COLORS['title']
                },
                margin: 25
            },
            labels: {
                overflow: 'justify',
                style: {
                    fontSize: '12px',
                    color: REPORT_COLORS['label']
                }
            },
            gridLineWidth: 1,
            gridLineColor: REPORT_COLORS['gridLineColor'],
            gridLineDashStyle: 'dot',
            minorGridLineWidth: 0,
            lineColor: REPORT_COLORS['lineColor'],
            lineWidth: 1,
            startOnTick: true,
            endOnTick: false,
        }, {
            min: 0,
            title: {
                text: null
            },
            lineColor: REPORT_COLORS['lineColor'],
            lineWidth: 1,
            opposite: true
        }],
        colors: REPORT_COLORS["series_colors"],
        legend: {
            borderWidth: 0,
            itemStyle: {
                bottom: 0,
                top: 'auto',
                fontWeight: 'normal'
            },
            verticalAlign: 'bottom',
            floating: false,
            itemDistance: 50
        },
        plotOptions: {
            series: {
                shadow: false,
                lineWidth: 3,
                animation: {
                    duration: 1000
                },
                marker: {
                    enabled: true,
                    radius: 1
                }
            },
            line: {
                marker: {
                    enabled: true,
                    radius: 1
                }
            }
        },
        tooltip: {
            formatter: opts['yAxis_label'] === 'Hours' ? this.hrPerformancelineTooltip : this.minPerformancelineTooltip,
            crosshairs: {
                color: 'gray',
                dashStyle: 'solid',
                width: 1
            },
            shared: true,
            useHTML: true,
            backgroundColor: REPORT_COLORS['tooltip_bg'],
            borderColor: 'none',
            shadow: false,
            style: {
                padding: 0
            },
            hideDelay: 50
        },
        series: opts['chartData']
    });
}
perfLineChart.prototype = new helpdeskReports;
perfLineChart.prototype.updateDefaultCharts();
perfLineChart.constructor = perfLineChart;

perfLineChart.prototype.perfLineChartGraph = function () {
    var chart = new Highcharts.Chart(this.options);
}

