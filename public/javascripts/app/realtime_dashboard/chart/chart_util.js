
REPORT_COLORS = {
    plotBG           : "rgba(255,255,255,0.1)",
    title            : "#999999",
    label            : "#333333",
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
    gridLineColor    : "#dedede",
    bucket_series    : ['#6FB5EC', '#FFCA7E'],
    stack_color      : {
                        'unresolved_tickets_by_priority': ["#90C765", "#36A2F2","#F9BE4B","#DD3034"],
                        'unresolved_tickets_by_status': ["#617b42", "#89ae5d", "#b1dd7b","#d5e9be","#d4d4d4"],
                        'unresolved_tickets_by_ticket_type': ["#D4F1FE", "#97DCFD","#1486C4","#5BB8E4","#D4D4D4"]
                       },
    scrollbar : {
        track_background : '#f2f2f2',
        button_background : '#bebebe',
        track_border : '#e9e9e9',
    }
}


function lineChart(opts){
    var config = {
        chart: {
            renderTo: opts['container'],
            type : 'line',
            borderColor: REPORT_COLORS['borderColor'],
            plotBackgroundColor: REPORT_COLORS['plotBG'],
            backgroundColor: REPORT_COLORS['plotBG'],
            height : opts.height,
            events : {
                click : function(e) {
                    if(opts['chartClick'] != undefined) {
                        opts['chartClick'].call(this,e);
                    }
                }
            },
            style: {
                fontFamily: '"Helvetica Neue", Helvetica, Arial'
            }
        },
        credits: {
           enabled: false
        },
        title: {
            text: opts['title'],
            x: -20 //center
        },
        colors: opts['colors'],
        plotOptions: {
            series: {
                shadow: false,
                lineWidth: 2,
                animation: {
                    duration: 1000,
                    easing: 'easeInOutQuart'
                },
                marker: {
                    enabled: false,
                    radius: 0
                },
                cursor : 'pointer',
                states: {
                    hover: {
                        enabled: opts['series_hover']
                    }
                }
            },
            line: {
                allowPointSelect : false,
                events: {
                    click : opts['chartClick'] != undefined ? opts['chartClick'] : function(){},
                    mouseOut: opts['total_action'] != undefined ? opts['total_action'] : function(){},
                    mouseOver : opts['hover_callback']
                }
            }
        },
        xAxis: {
            categories: opts['categories'],
            labels : {
                formatter : opts['formatter'] != 'undefined' ? opts['formatter'] : function(){ return this.value},
                step : 1,
                style : {
                    fontSize : '11px',
                    color : REPORT_COLORS['label']
                }
            },
            tickInterval : 2
        },
        yAxis: {
            min: 0,
            allowDecimals: false,
            max: (typeof opts['yMax'] !== 'undefined') ? opts['yMax'] : null,
            title: {
                text: opts['yAxis_label'],
                align: 'middle',
                style: {
                    fontSize: '11px',
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
            gridLineDashStyle: 'solid',
            minorGridLineWidth: 0,
            lineColor: REPORT_COLORS['lineColor'],
            lineWidth: 1,
            startOnTick: true,
            max : opts['yMax']
        },
        legend: {
            enabled : opts['legend'] == true ? true : false,
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
        series: opts['series'],
        exporting: { enabled: false },
        tooltip : {
            shared : true,
            formatter: opts['tooltip_callback'],
            crosshairs: opts['crosshairs'],
            backgroundColor: '#333',
            borderColor: '#333',
            style : {
                color : '#fff'
            },
            borderRadius : 6
        }
    }

    new Highcharts.Chart(config);
}

function stackedColumnGraph(opts) {

    var config = {
        chart: {
            renderTo: opts['container'],
            type: 'column',
            height: opts.height,
            plotBackgroundColor : REPORT_COLORS['REPORT_COLORS'],
            events : {
                click : function(e) {
                    if(opts['chartClick'] != undefined) {
                        opts['chartClick'].call(this,e);
                    }
                }
            },
            style: {
                fontFamily: '"Helvetica Neue", Helvetica, Arial'
            }
        },
        credits: {
           enabled: false
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
                    fontSize: '11px',
                    color: REPORT_COLORS['label'],
                    fontFamily: "Helvetica Neue"
                },
                formatter: opts['formatter'],
                autoRotation : false
            },
            tickLength: 1,//opts['tick'] != undefined ? opts['tick'] : 0,
            minorTickLength: 0,
            lineColor: REPORT_COLORS['lineColor']
        },
        yAxis: {
            allowDecimals: false,
            title: {
                text: (typeof opts['yAxis_label'] === 'undefined') ? '' : opts['yAxis_label'],
                align: 'middle',
                style: {
                    fontSize: '12px',
                    color: REPORT_COLORS['title'],
                    fontFamily: "Helvetica Neue"
                }
            },
            labels: {
                overflow: 'justify',
                style: {
                    fontSize: '12px',
                    color: REPORT_COLORS['label'],
                    fontFamily: "Helvetica Neue"
                }
            },
            gridLineWidth: opts['gridLineWidth'] != 'undefined' ? opts['gridLineWidth'] : 0,
            minorGridLineWidth: 0,
            startOnTick: true,
            lineColor: 'transparent',//REPORT_COLORS['lineColor'],
            lineWidth: 0
        },
        colors: REPORT_COLORS["stack_color"][opts.type],
        plotOptions: {
            column: {
                stacking: 'normal',
                shadow : false,
                borderWidth: 0,
                events: {
                    click : opts['chartClick'] != undefined ? opts['chartClick'] : function(){},
                    mouseOut: opts['total_action'] != undefined ? opts['total_action'] : function(){},
                    mouseOver : opts['hover_callback'] != undefined ? opts['hover_callback'] : function(){}
                },
                pointWidth : 35
            },
            series: {
                animation: {
                    duration: 1000,
                    easing: 'easeInOutQuart'
                },
                cursor: 'pointer',
                states: {
                    hover: {
                        enabled: false
                    }
                }
            }
        },
        tooltip: {
            formatter: function() {
                if(opts['enableHover'] != 'undefined' && opts['enableHover']) {
                    if(opts['tooltip_callback'] != undefined) {
                        opts['tooltip_callback'].call(this);  
                        return false;  
                    } 
                } else {
                    return false;
                }
            },
            useHTML: true,
            shared : true
        },
        series: opts['chartData'],
        exporting: { enabled: false },
        legend: {
            enabled : opts['legend'] == true ? true : false,
            borderWidth: 0,
            itemStyle: {
                fontWeight: 'normal',
                textTransform: "capitalize",
                fontSize : '11px',
                color : '#888',
                cursor : 'pointer',
                fontFamily: "Helvetica Neue"
            },
            verticalAlign: 'bottom',
            floating: false,
            itemDistance: 10,
            x : -10,
            symbolWidth : 10,
            symbolHeight : 10,
            align : 'left'
        },
        scrollbar: {
            enabled: opts['scrollbar'],
            barBackgroundColor: '#c6c6c6',
            barBorderRadius: 3,
            barBorderWidth: 0,
            buttonBackgroundColor: '#c6c6c6',
            buttonBorderWidth: 0,
            buttonArrowColor: 'rgba(0,0,0,0)',
            buttonBorderRadius: 7,
            rifleColor: '#c6c6c6',
            trackBackgroundColor: REPORT_COLORS['scrollbar']['track_background'],
            trackBorderWidth: 1,
            trackBorderColor: REPORT_COLORS['scrollbar']['track_border'],
            trackBorderRadius: 3,
            height : 6
        }
    };
    if(opts['max'] != undefined) {
        config.xAxis.max = opts['max'];
    }
    if(opts['yMax'] != undefined) {
        config.yAxis.max = opts['yMax'];
    }
    if(opts['showYAxis'] != undefined && opts['showYAxis']) {
        config.yAxis.lineColor = REPORT_COLORS['lineColor'];
        config.yAxis.lineWidth = 1;
    }
    if(opts['showYAxisLabels'] != undefined && opts['showYAxisLabels']) {
       config.yAxis.labels.enabled = true;
    } else {
       config.yAxis.labels.enabled = false;
    }

    if(opts['chartCursor'] != undefined && opts['chartCursor']) {
        config.chart.style = {};
        config.chart.style.cursor = 'pointer';
    }
    if(opts['crossHair'] != undefined && opts['crossHair']) {
        config.xAxis.crosshair = {};
        config.xAxis.crosshair.color = '#eeeeee';
    }
    new Highcharts.Chart(config);
}

/*
 * Used for Group & Agent Performance Graphs
 */
function multiSeriesColumn(opts) {
    var config = {
        chart: {
            renderTo: opts['container'],
            type: 'column',
            borderRadius: 0,
            height: opts['height'],
            events : {
                click : function(e) {
                    if(opts['chartClick'] != undefined) {
                        opts['chartClick'].call(this,e);
                    }
                }
            },
            style: {
                fontFamily: '"Helvetica Neue", Helvetica, Arial'
            }
        },
        credits: {
           enabled: false
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
                style : {
                    fontSize : '11px',
                    color : REPORT_COLORS['label'],
                    fontFamily: "Helvetica Neue"
                },
                autoRotation : false
            },
            title: {
                text: (typeof opts['xAxis_title'] === 'undefined') ? null : opts['xAxis_title'],
                align: 'middle',
                style: {
                    fontSize: '13px',
                    color: REPORT_COLORS['title'],
                    fontFamily: "Helvetica Neue"
                },
                margin: 25
            },
            lineWidth: 1,
            tickLength : 1,//opts['tick'] != undefined ? opts['tick'] : 0,
            lineColor: REPORT_COLORS['gridLineColor'],
            gridLineWidth: 0
        },
        yAxis: {
            min: 0,
            title: {
                text: (typeof opts['yAxis_title'] === 'undefined') ? null : opts['yAxis_title'],
                align: 'middle',
                style: {
                    fontSize: '12px',
                    color: REPORT_COLORS['title'],
                    fontFamily: "Helvetica Neue"
                },
            },
            allowDecimals: false,
            gridLineWidth: opts['gridLineWidth'] != 'undefined' ? opts['gridLineWidth'] : 0,
            lineWidth: 0,
            lineColor: REPORT_COLORS['gridLineColor'],
            labels : {
                enabled : opts['label_enabled'] != 'undefined' && !opts['label_enabled'] ? false : true,
                style : {
                    fontFamily: "Helvetica Neue"
                }
            }
        },
        colors: REPORT_COLORS["series_colors"],
        plotOptions: {
            column : {
                events: {
                    mouseOut: opts['total_action'] != undefined ? opts['total_action'] : function(){},
                    mouseOver : opts['hover_callback'] != undefined ? opts['hover_callback'] : function(){},
                    click : opts['chartClick'] != undefined ? opts['chartClick'] : function(){}
                }
            },
            series: {
                shadow: false,
                groupPadding: 0,
                animation: {
                    duration: 1000,
                    easing: 'easeInOutQuart'
                },
                stickyTracking : false,
                states: {
                    hover: {
                        enabled: false
                    }
                }
            }
        },
        tooltip: {
            useHTML: true,
            enabled : true,
            formatter: function() {
                if(opts['enableHover'] != 'undefined' && opts['enableHover']){
                    if(opts['tooltip_callback'] != 'undefined') {
                        opts['tooltip_callback'].call(this);
                    }
                    return false;
                } else {
                    return false;
                }
            },
            shared : true
        },
        series: opts['chartData'],
        legend: {
            enabled : opts['legend'] == true ? true : false, 
            borderWidth: 0,
            itemStyle: {
                fontWeight: 'normal',
                textTransform: "capitalize",
                fontSize : '11px',
                color : '#888',
                cursor : 'pointer',
                fontFamily : "Helvetica Neue"
            },
            verticalAlign: 'bottom',
            itemDistance: 10,
            x : -10,
            symbolWidth : 10,
            symbolHeight : 10,
            align : 'left'
        },
        exporting: { enabled: false },
        scrollbar: {
            enabled: opts['scrollbar'],
            barBackgroundColor: '#c6c6c6',
            barBorderRadius: 3,
            barBorderWidth: 0,
            buttonBackgroundColor: '#c6c6c6',
            buttonBorderWidth: 0,
            buttonArrowColor: 'rgba(0,0,0,0)',
            buttonBorderRadius: 7,
            rifleColor: '#c6c6c6',
            trackBackgroundColor: REPORT_COLORS['scrollbar']['track_background'],
            trackBorderWidth: 1,
            trackBorderColor: REPORT_COLORS['scrollbar']['track_border'],
            trackBorderRadius: 3,
            height : 6
        }
    }
    if(opts['max'] != undefined) {
        config.xAxis.max = opts['max'];
    }
    if(opts['yMax'] != undefined) {
        config.yAxis.max = opts['yMax'];
    }
    if(opts['showYAxis'] != undefined && opts['showYAxis']) {
        config.yAxis.lineColor = REPORT_COLORS['lineColor'];
        config.yAxis.lineWidth = 1;
    }
    if(opts['showYAxisLabels'] != undefined && opts['showYAxisLabels']) {
       config.yAxis.labels.enabled = true;
    } else {
       config.yAxis.labels.enabled = false;
    }
    if(opts['chartCursor'] != undefined && opts['chartCursor']) {
        config.chart.style = {};
        config.chart.style.cursor = 'pointer';
    }
    if(opts['crossHair'] != undefined && opts['crossHair']) {
        config.xAxis.crosshair = {};
        config.xAxis.crosshair.color = '#eeeeee';
    }
    new Highcharts.Chart(config);
}

function barChart(opts) {
    var config = {
        chart: {
            renderTo: opts['renderTo'],
            type: 'bar',
            plotBackgroundColor: REPORT_COLORS['plotBG'],
            backgroundColor: REPORT_COLORS['plotBG'],
            borderRadius: 0,
            height: opts['height'],
            style: {
                fontFamily: '"Helvetica Neue", Helvetica, Arial'
            }
        },
        credits: {
           enabled: false
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
                    fontSize: '12px',
                    textAlign: 'right',
                    whiteSpace: 'nowrap',
                    color : REPORT_COLORS['label']
                },
                x : 0,
                y : -13,
                align : 'left'
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
                    fontSize: '15px',
                    fontWeight: 400,
                    color : REPORT_COLORS['label']
                },
                useHTML : true,
                x : -10,
                y : -13,
                align : 'right'
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
                enabled: false,
            },
            max: opts['yAxisMaxValue'] === undefined ? null : opts['yAxisMaxValue'],
            gridLineWidth: 0,
            minorGridLineWidth: 0,
            minPadding: 0,
            maxPadding: 0,
            endOnTick: false
        },
        plotOptions: {
            bar: {
                pointWidth: 9,
                grouping: false,
                minPointLength: opts['minPoint'] === undefined ? 0 : 2
            }
        },
        tooltip: {
            useHTML: true,
            shared: opts['sharedTooltip'],
            //opts['sharedTooltip'] == true ? ( opts['performanceDistTooltip'] ? this.performanceDistributionBarChartTooltip : this.barChartTooltip) : this.barChartSLATooltip,
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
        exporting: { enabled: false },
        legend: {
            enabled: false
        }
    };
    if(opts['width'] != undefined) {
        config.chart.width = opts['width'];
    }
    new Highcharts.Chart(config);
}


function progressGauge(opts) {

    var config = {
        chart: {
            type: 'solidgauge',
            renderTo: opts['container']
        },
        title: null,
        pane: {
            center: ['50%', '50%'],
            size: '100%',
            startAngle: 0,
            endAngle: 360,
            background: {
                backgroundColor: '#EBEBEB',
                innerRadius: '60%',
                outerRadius: '100%',
                shape: 'arc',
                borderWidth: 0
            }
        },

        tooltip: {
            enabled: false
        },

        // the value axis
        yAxis: {
            lineWidth: 0,
            minorTickInterval: null,
            tickPixelInterval: 400,
            tickWidth: 0,
            title: {
                y: -70
            },
            labels: {
                enabled:false
            },
            min : 0,
            max : opts['max']
        },
        credits: {
            enabled: false
        },
        plotOptions: {
            solidgauge: {
                dataLabels: {
                    y: 0,
                    borderWidth: 0,
                    useHTML: true,
                    style: {
                        fontWeight: 'normal',
                        fontSize : '10px'
                    },
                    verticalAlign: 'middle',
                    overflow: true,
                    crop: false
                }
            }
        },
        series : opts['series']
    };

    new Highcharts.Chart(config);
}