REPORT_COLORS = {
    'plotBG'        : "rgba(255,255,255,0.1)",
    'title'         : "#999999",
    'label'         : "#191919",
    'lineColor'     : '#EBEBEB',
    'miniChartBG'   : '#F1F1F1',
    'alternateBG'   : "#F4FBFF",
    'miniActive'    : "#333333",
    'miniAlt'       : "#555555",
    'series_colors' : ['#1387C2', '#80B447']
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
        if ((this.point.y) % 1 === 0) {
            return '<p style="color:' + this.point.series.color + '">' + 'Total Tickets ' + this.series.name + '<strong> : ' + (this.point.y).toFixed(0) + '</strong> </p>';
        } else {
            return '<p style="color:' + this.point.series.color + '">' + 'Total Tickets ' + this.series.name + '<strong> : ' + (this.point.y).toFixed(2) + '</strong> </p>';
        }
    },
    columnChartLabel: function () {
        var trend = HelpdeskReports.CoreUtil.trend;
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
        var x = "";
        var active_day = HelpdeskReports.CoreUtil.active_day;        
        jQuery.each(this.points, function (i, point) {
            var y = (point.y) % 1 === 0 ? (this.y) : (this.point.y).toFixed(2);
            x += '<span style="color:' + point.series.color + '">Average Tickets ' + point.series.name + '</span>: ' + y + '<br/>';
        });
        x += "(Avg of all " + active_day + ")"; 
        return x;
    },
}


function columnChart(opts) {
    helpdeskReports.call(this, {
        chart: {
            renderTo: opts['renderTo'],
            type: 'column',
            borderColor: 'rgba(0,0,0,0)',
            plotBackgroundColor: REPORT_COLORS['plotBG'],
            backgroundColor: REPORT_COLORS['plotBG'],
            height: 350,
            zoomType: 'x'
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
                formatter: this.columnChartLabel
            },
            tickLength: 0,
            minorTickLength: 0,
            lineColor: REPORT_COLORS['lineColor'],
        },
        yAxis: {
            min: 0,
            title: {
                text: (typeof opts['yAxis_label'] === 'undefined') ? 'No. of Tickets' : opts['yAxis_label'],
                align: 'middle',
                style: {
                    fontSize: '12px',
                    color: REPORT_COLORS['title']
                }
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
            lineWidth: 1
        },
        colors: REPORT_COLORS["series_colors"],
        plotOptions: {
            column: {
                borderWidth: 0,
                pointPadding: 0,
                dataLabels: {
                    enabled: !! opts['isPDF'],
                    style: {
                        fontSize: '11px',
                    },
                    overflow: 'justify',
                    align: 'left',
                    y: 0,
                    formatter: this.columnChartDataLabels
                },
                animation: opts['isPDF'] ? false : true
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
                    duration: 500
                }
            }
        },
        tooltip: {
            style: {
                fontSize: '11px',
                padding: 5
            },
            formatter: this.columnChartTooltip,
            borderWidth: 1,
            borderColor: 'transparent',
            borderRadius: 0
        },
        series: opts['chartData'],
        legend: {
            borderWidth: 0,
            style: {
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
            borderColor: 'rgba(0,0,0,0)',
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
                }
            },
            title: {
                text: (typeof opts['xAxis_label'] === 'undefined') ? 'Hour of the day' : opts['xAxis_label'],
                align: 'middle',
                style: {
                    fontSize: '13px',
                    color: REPORT_COLORS['title']
                }
            },
            tickLength: 0,
            minorTickLength: 0,
            lineColor: REPORT_COLORS['lineColor']
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
            max: (typeof opts['yMax'] !== 'undefined') ? opts['yMax'] : null,
            title: {
                text: (typeof opts['yAxis_label'] === 'undefined') ? 'Avg no. of tickets' : opts['yAxis_label'],
                align: 'middle',
                style: {
                    fontSize: '13px',
                    color: REPORT_COLORS['title']
                }
            },
            labels: {
                overflow: 'justify',
                style: {
                    fontSize: '12px',
                    color: REPORT_COLORS['label']
                }
            },
            gridLineWidth: 1,
            gridLineDashStyle: 'dot',
            minorGridLineWidth: 0,
            lineColor: REPORT_COLORS['lineColor'],
            lineWidth: 1
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
                    duration: 500
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
            style: {
                fontSize: '11px',
                padding: 5
            },
            formatter: this.lineChartTooltip,
            crosshairs: {
                color: 'gray',
                dashStyle: 'solid',
                width: 1
            },
            shared: true,
            borderWidth: 1,
            borderColor: 'transparent',
            borderRadius: 0
        },
        series: opts['chartData'],
        legend: {
            borderWidth: 0,
            style: {
                bottom: 0,
                top: 'auto',
                fontWeight: 'normal'
            },
            verticalAlign: 'bottom',
            floating: false
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
            minorGridLineWidth: 0
        },
        colors: REPORT_COLORS["series_colors"],
        plotOptions: {
            series: {
                shadow: false,
                enableMouseTracking: false
            },
            line: {
                marker: {
                    enabled: false
                }
            },
            animation: {
                duration: 500
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