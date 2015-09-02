REPORT_COLORS = {
    plotBG          : "rgba(255,255,255,0.1)",
    title           : "#999999",
    label           : "#191919",
    lineColor       : '#EBEBEB',
    miniChartBG     : '#F1F1F1',
    alternateBG     : "#F4FBFF",
    miniActive      : "#333333",
    miniAlt         : "#555555",
    series_colors   : ['#1387C2', '#80B447'],
    borderColor     : 'rgba(0,0,0,0)',
    tooltip_bg      : "rgba(0,0,0,0.6)",
    barChartDummy   : "#F8F8F8",
    barChartReal    : "#5194CC",
    barChartPercent : "#CFA495",
    gridLineColor   : "#f0f0f0",
    bucket_series   : ['#FFCA7E', '#6FB5EC']
}

COLUMN_SERIES = {
    'Received': "RECEIVED_TICKETS",
    'Resolved': "RESOLVED_TICKETS"
}
// TODO: Namespace it to helpdesk reports
function helpdeskReports(opts) {
    this.options = {
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
        if (this.point.series.index == 0) {
            return '<div class="tooltip"> <p style="margin:0;color:#63b3f5;font-size: 13px;font-weight: 500">' + 'Total Tickets ' + this.series.name + '<strong> : ' + (this.point.y).toFixed(0) + '</strong></p></div>';
        } else {
            return '<div class="tooltip"> <p style="margin:0;color:#64b740;font-size: 13px;font-weight: 500">' + 'Total Tickets ' + this.series.name + '<strong> : ' + (this.point.y).toFixed(0) + '</strong></p></div>';
        }
    },
    xAxisTrendLabel: function() {    
        var trend = HelpdeskReports.locals.trend;
        var value = this.value;
        //TODO: 
        if (typeof value == 'string') {
            switch (trend) {

            case 'doy':
                var regex = /^(.*?)\,/;
                return regex.exec(value)[1];

            case 'w':
                var regex = /^(.*?)\,/;
                return regex.exec(value)[1];

            case 'mon':
                
                var d = Date.parse(value);
                if (d.getMonth() == 0 || this.isFirst) {
                    return value;
                } else {
                    var regex = /^(.*?)\,/;
                    return regex.exec(value)[1];
                }   

            case 'qtr':
                var regex = /^(.*?)\,/;
                var exp = regex.exec(value)[1];
                exp = exp.split('-')[0];
                var d = Date.parse(exp);
                if  (d.getMonth() == 0 || this.isFirst) {
                    return value;
                } else {
                    return exp;
                }

            case 'y':
               return value;

            }
        }
    },
    columnChartDataLabels: function () {
        if (this.y > 0) return this.y;
    },
    lineChartTooltip: function () {
        var active_day = HelpdeskReports.locals.active_day;
        var x = "<div class='tooltip'>";
        jQuery.each(this.points, function (i, point) {
            var y = (point.y) % 1 === 0 ? (this.y) : (this.point.y).toFixed(2);
            x += '<p style="margin:0;display:inline-block;color:' + point.series.color + '">Average Tickets ' + point.series.name + ' : ' + y + '</p><br/>';
        });
        if(active_day){
            x += "(Avg of all " + active_day + ")"; 
        }
        x += "</div>";
        return x;
    },
    performancelineTooltip: function () {
        var x = "<div class='tooltip'>";
        jQuery.each(this.points, function (i, point) {
            var y = (point.y) % 1 === 0 ? (this.y) : (this.point.y).toFixed(2);
            x += '<p style="margin:0;display:inline-block;color:' + point.series.color + '">' + point.series.name + ' : ' + helpdeskReports.prototype.daysLabelFormatter(y) + '</p><br/>';
        });
        x += "</div>";
        return x;
    },
    barChartTooltip: function () {
        var series = this.series.index;
        var fp,sp;
        if (series == 1) {
            fp = this.y;
            return '<div class="tooltip"><p style="margin:0;color:#63b3f5;"> Compliant: '+ fp +'% </p></div>'
        } else {
            var index = this.series.data.indexOf(this.point);
            var point = parseInt(100 - this.series.chart.series[1].data[index].y);
            return '<div class="tooltip"><p style="margin:0;color:#f48f6c;"> Violated: ' + point + '%</p></div>';
        }
        
    },
    barChartSeriesTooltip: function () {
        if (this.point.series.index == 0) {
            return '<div class="tooltip"><p style="margin:0;color:#ffe397;">'+ this.y  + ' Tickets with ' + this.x + ' ' + this.series.name + '<br/></p></div>';
        } else {
            return '<div class="tooltip"><p style="margin:0;color:#63b3f5;">'+ this.y  + ' Tickets with ' + this.x + ' ' + this.series.name + '<br/></p></div>';
        }
    },
    daysLabelFormatter: function (min) {
        var m = this.value || min;
        if (m == 0 || typeof m === 'undefined' ) 
            return '0h 0m';
        var h = Math.floor(m / 60);
        var min = Math.floor(m) % 60;
        return h + 'h ' + min + 'm';
    },
    barLabelFormatter: function () {
        var s = this.value;
        var r = "",str="",p;
        var lastAppended = 0;
        var lastSpace = -1;
        var breakCount = 0;
        for (var i = 0; i < s.length; i++) {
            if (s.charAt(i) == ' ') lastSpace = i;
            if (i - lastAppended > 11) {
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
            height: 350
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
                text: (typeof opts['yAxis_label'] === 'undefined') ? 'No. of Tickets' : opts['yAxis_label'],
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
            startOnTick: true,
            endOnTick: false
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
                //Commenting out ticket_list code for first cut
                //cursor: 'pointer',
                // point: {
                //     events: {
                //         click: function () {
                //             trigger_event("timetrend_point_click", {
                //                 sub_metric: COLUMN_SERIES[this.series.name],
                //                 date: this.category
                //             });
                //         }
                //     }
                // },
                animation: {
                    duration: 1000
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
            }
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
                useHTML : true
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
            min: opts['report_type'] === 'perf' ? null : 0.5,
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
                text: (typeof opts['yAxis_label'] === 'undefined') ? 'Avg no. of Tickets' : opts['yAxis_label'],
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
            endOnTick: false
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
            formatter: opts['report_type'] === 'perf' ? this.performancelineTooltip : this.lineChartTooltip,
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
            }
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
            borderRadius: 0
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
                    duration: 1000
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
                    //wordWrap:'break-word',
                },
                formatter: this.barLabelFormatter,
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
                formatter: opts['timeFormat'] == true ? this.daysLabelFormatter : null
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
            gridLineWidth: 0,
            minorGridLineWidth: 0,
            minPadding: 0,
            maxPadding: 0
        },
        plotOptions: {
            bar: {
                pointWidth: 12,
                grouping: false
                //cursor: 'pointer'
            },
        },
        tooltip: {
            useHTML: true,
            shared: opts['sharedTooltip'],
            formatter: opts['sharedTooltip'] == true ? null : this.barChartTooltip,
            followPointer: true,
            enabled: opts['sharedTooltip'] == true ? false : true,
            backgroundColor: REPORT_COLORS['tooltip_bg'],
            borderColor: 'none',
            shadow: false,
            style: {
                padding: 0
            }
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
            lineWidth: 0,
            gridLineWidth: 1,
            gridLineColor: REPORT_COLORS['gridLineColor'],
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
            gridLineWidth: 1,
            gridLineColor: REPORT_COLORS['gridLineColor'],
        },
        colors: REPORT_COLORS["bucket_series"],
        plotOptions: {
            bar: {
                borderWidth: 0,
                pointPadding: 0
            },
            series: {
                shadow: false,
                groupPadding: 0.3,
                animation: {
                    duration: 1000
                }
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
            }
        },
        series: opts['chartData'],
        legend: {
            borderWidth: 0,
            itemStyle: {
                bottom: 0,
                top: 'auto',
                fontWeight: 'normal',
                cursor: 'pointer'
            },
            verticalAlign: 'bottom'
        }
    });
}
barChartMultipleSeries.prototype = new helpdeskReports;
barChartMultipleSeries.prototype.updateDefaultCharts();
barChartMultipleSeries.constructor = barChartMultipleSeries;

barChartMultipleSeries.prototype.barChartSeriesGraph = function () {
    var chart = new Highcharts.Chart(this.options);
}

