function adv_grid_report(opts){
    this.options = {
      credits: {
        enabled: false
      },
      chart:{
        style:{fontFamily:'"Helvetica Neue", Helvetica, Arial'}
      },
      tooltip: {
          xDateFormat: '%d/%m/%Y %H:%M:%S'
      },
      title: {
        text: ''
      },
      isPDF: false
    };
    this.options = jQuery.extend(this.options,opts);
}

adv_grid_report.prototype = {
  update_default_charts: function(){
      Highcharts.setOptions(this.options);
  },
  gauge_label_formatter: function(){
    return '<strong>' + this.y  + '%</strong> '
  },
  pie_label_formatter: function() {
	 if(this.percentage > 3) return (this.percentage).toFixed(1) + '<span style=\"font-size:11px\">%</span>' ;
	},
	stack_bar_single_tooltip_formatter: function() {
	  return '<strong>' + this.series.name  + '</strong> ' + (this.percentage).toFixed(1)+ '% ('+this.point.count+' tickets)';
	},
	pie_tooltip_formatter : function() {
    return "<strong>" + this.point.name + "</strong>: " +  (this.percentage).toFixed(1) + "% ("+this.point.count+" tickets)";
  },
  pie_legend_formatter : function() {
    return this.name ;
  },
  pareto_tooltip_formatter : function(){
  	return '<p>' + this.point.name  + '<strong> : ' +this.point.y+ '%</strong> ('+this.point.count+' tickets)</p>';
  },
  pareto_category_formatter : function(){
  	value = this.value;
    if(value.length > 15){
      value =value.substring(0,15);
      value =value+'...';
    }
    return value;
  },
  pareto_label_formatter : function(){
  	if(this.y>0)  return  this.point.y+'%' ;
  },
  line_tooltip_formatter : function() {
    var s = '<b>'+ new Date(this.x).toString('MMM dd, yyyy') +'</b>';
    jQuery.each(this.points, function(i, point) {
      var _point_y = (point.y) % 1 === 0 ? (this.y).toFixed(0) : (this.y).toFixed(2);
      s += '<br/><span style="color:'+point.series.color+'">'+ point.series.name +'</span>: '+ _point_y;
    });
    
    return s;
  },
  barGraph_tooltip_formatter : function(){
    if(this.point.tool_tip_label){
      return '<p>' + this.point.name  + '<strong> : ' +this.point.y+ '% </strong> ('+this.point.count+' tickets)</p>';
    } else{
      return '<p>' + this.point.name  + '<strong> : ' +this.point.y+ ' Tickets</strong></p>';
    }
  },
  xAxisGraph_tooltip_formatter : function(){
    if((this.point.y) % 1 === 0){
      return '<p>' + this.series.name  + '<strong> : ' +(this.point.y).toFixed(0)+ '</strong> </p>';
    }else{
      return '<p>' + this.series.name  + '<strong> : ' +(this.point.y).toFixed(2)+ '</strong> </p>';
    }
  },
  xaxis_bar_dataLabels: function(){
    if(this.y>0) return this.y;
  },
  bar_dataLabels_tooltip: function(){
    var text      = this.value,
        formatted = text.length > 25 ? text.substring(0, 25) + '...' : text;
    return '<div class="tooltip" style="width:50px; overflow:hidden; cursor:pointer" title="' + text + '">' + formatted.replace(' ','<br/>') + '</div>'; 
  }
}

function gaugeChart(opts){
  adv_grid_report.call(this,{
    chart: {
	    renderTo: opts['renderTo'],
	    type: 'gauge',
	    borderColor: 'fff',
	    plotBackgroundColor: null,
	    plotBackgroundImage: null,
	    plotBorderWidth: 0,
	    plotShadow: false,
	    plotBorderColor: 'fff'
    },
    title: {
      text: (typeof opts['chartText'] === 'undefined') ? '' : opts['chartText'],
      style: {fontSize: '15px'}
    },
    
    pane: {
      startAngle: -90,
      endAngle: 90,
      background: null,
      size: 100
    },
       
    // the value axis
    yAxis: {
      min: 0,
      max: 100,
      
      tickWidth: 0,
      minorTickWidth: 0,
      labels: {
        step: 1,
        rotation: 'auto'
      },
      title: {
        text: opts['yAxisText']
      },
      plotBands: [{
        from: 0,
        to: 30,
        color: '#DF5353' // red
      }, {
        from: 30,
        to: 60,
        color: '#DDDF0D' // yellow
      }, {
        from: 60,
        to: 100,
        color: '#55BF3B' // green
      }]        
    },

    plotOptions: {
      gauge: {
        dial: {
          radius:'90%'
        },
        dataLabels:{
          enabled: opts['isPDF'] ? true : false,
          formatter: this.gauge_label_formatter
        },
        animation: opts['isPDF'] ? false : true
      }
    },

    series: [{
      name: opts['tooltipName'],
      data: opts['chartData'],
      tooltip: {
        valueSuffix: opts['valueSuffix']
      }
    }]
  });
};

gaugeChart.prototype = new adv_grid_report;
gaugeChart.constructor = gaugeChart;

gaugeChart.prototype.gaugeChartGraph = function(){
    var chart = new Highcharts.Chart(this.options);
}

function single_stacked_bar_chart(opts){
	adv_grid_report.call(this,{
  	chart: {
        renderTo: opts['renderTo'],
        type: 'bar',
        borderColor: 'rgba(0,0,0,0)',
        margin:[10,5,10,5]
    },

    xAxis: {
    	categories: ['Tickets'],
    	gridLineColor: '#FFFFFF',
    	gridLineWidth: 0,
    	minorGridLineWidth: 0,
    	tickWidth:0,
    	lineWidth:0,
    	labels: {
    		enabled: false
    	}
    },
       
    yAxis: {
      gridLineColor: 'FFFFFF',
      title: 'Tickets',
      min: 0,
      lineWidth: 0,
      gridLineWidth: 0,
      minorGridLineWidth: 0,
      labels: {
      	enabled: false
      }
    },

    plotOptions: {
    	series: {
    		stacking: 'normal'
    	},
    	bar: {
    		borderWidth: 0,
    		shadow: false,
    		dataLabels: {
    			enabled: true,
    			formatter: this.pie_label_formatter,
    			color: '#eee',
    			align: 'center',
    			y: 0,
    		},
    		showInLegend : true,
        animation: opts['isPDF'] ? false : true
    	}
    },

    legend: {
    	layout: 'horizontal',
    	align: 'center',
      itemStyle: {
        fontFamily:'"Helvetica Neue", Helvetica, Arial'
      },
    	style: {
    		left: 40,
    		top: 75
    	},
    	borderWidth: 0,
    	y: 0,
    	reversed: true,
    	verticalAlign: 'top',
    	floating: false
    },

    credits: {
      enabled:false
    },

    tooltip: {
    	formatter: this.stack_bar_single_tooltip_formatter
    },

    series: opts['chartData']
  });
}

single_stacked_bar_chart.prototype = new adv_grid_report;
single_stacked_bar_chart.constructor = single_stacked_bar_chart;

single_stacked_bar_chart.prototype.single_stacked_bar_chart_Graph = function(){
    var chart = new Highcharts.Chart(this.options);
}

function pieChart(opts){
	adv_grid_report.call(this,{
  	chart: {
      style:{fontFamily:'"Helvetica Neue", Helvetica, Arial'},
	    renderTo: opts['renderTo'],
	    type: 'bar',
	    borderColor: 'rgba(0,0,0,0)',
	    margin:[00, 10, 0, 10]
	  },
    title: {
      text: (typeof opts['title'] === 'undefined') ? '' : opts['title'],
      style: {fontSize: '12px'},
    },
	  plotOptions: {
	  	pie: {
	    	size: '75%',
	      borderWidth: 0,
	      shadow: false,
	      dataLabels: {
	        enabled: true,
	        connectorWidth: 0,
	        distance: -25,
	        formatter: this.pie_label_formatter,
	        style: {
	          font: "6pt",
	          textTransform: "capitalize"
	        },
	      color: '#eee'
	      },
	      showInLegend: true,
        animation: opts['isPDF'] ? false : true
	    }
		},

	  legend: {
	    layout: 'horizontal',
	    align: 'center',
      itemStyle: {
        width: 350,
        fontFamily:'"Helvetica Neue", Helvetica, Arial'
      },
	    style: {
	      top: 300,
	      left: 2
	    },
	    borderWidth: 0,
      width:300,
	    y: 5,
	    verticalAlign: 'bottom',
	    floating: false,	        
	    labelFormatter: this.pie_legend_formatter
	  },

	  credits: {
	    enabled:false
	  },

	  tooltip: {
	  	formatter: this.pie_tooltip_formatter
	  },

	  series: [
	    {
	      type: 'pie',
	      data: opts['chartData'],
	      innerSize: '30%'
	    }
	  ]
  });
}

pieChart.prototype = new adv_grid_report;
pieChart.constructor = pieChart;

pieChart.prototype.pieChartGraph = function(){
    var chart = new Highcharts.Chart(this.options);
}


function lineChart(opts){
	adv_grid_report.call(this,{
    chart: {
      type: 'spline',
      renderTo: opts['renderTo'],
      margin: [10,30,80,70],
      zoomType: 'x',
      borderColor: 'rgba(0,0,0,0)'
    },
    title: {
      text: (typeof opts['title'] === 'undefined') ? '' : opts['title'],
      style: {fontSize: '12px'}
    },
    legend: {
      layout: 'horizontal',
      align: 'center',
      itemStyle: {
        fontFamily:'"Helvetica Neue", Helvetica, Arial'
      },
      style: {
        bottom: 0,
        top: 'auto',
        fontWeight: 'normal'
      },
      y: 15,
      verticalAlign: 'bottom',
      floating: false
    },
    xAxis: {
      type: 'datetime',
      allowDecimals: false,
      maxZoom: 4 * 24 * 3600000,
      dateTimeLabelFormats: { // don't display the dummy year
        month: '%e. %b',
        year: '%b'
      }
    },
    plotOptions: {
      line: {
        shadow: false,
        animation: opts['isPDF'] ? false : true,
        enableMouseTracking: opts['isPDF'] ? false : true,
        marker: {
          enabled: false
        }
      }
    },
    yAxis: {
      title: {
        text: opts['yAxisTitle'] ? opts['yAxisTitle'] : ''
      },
      min: 0,
      gridLineWidth: 1,
      allowDecimals: false,
      gridLineDashStyle: 'ShortDot',
      showFirstLabel: false
	  },
    series: opts['chartData'],

    tooltip: {
      shared: true,
      crosshairs: true,
      enabled: opts['isPDF'] ? false : true,
      formatter: this.line_tooltip_formatter
    }

	});
}

lineChart.prototype = new adv_grid_report;
lineChart.constructor = lineChart;

lineChart.prototype.lineChartGraph = function(){
    var chart = new Highcharts.Chart(this.options);
}

function pare_to_chart(opts){
	adv_grid_report.call(this,{
		chart: {
      renderTo: opts['renderTo'],
      type: 'bar',
      margin: [10,35,50,opts['column_width']],
      borderColor: 'rgba(0,0,0,0)',
      height: (opts['chartData'].length*20 < 320)? 320 : opts['chartData'].length*20,
      plotBackgroundColor: 'rgba(255,255,255,0.1)',
      backgroundColor: 'rgba(255,255,255,0.1)'
    },
    title: {
      text: (typeof opts['title'] === 'undefined') ? '' : opts['title'],
      style: {fontSize: '12px'}
    },
    xAxis: {
      gridLineColor: '#197F07',
      categories: opts['xaxis_arr'],
      tickWidth: 0,
      labels: {
        formatter: this.pareto_category_formatter,
        style: {
          font: 'normal 11px Helvetica Neue, sans-serif'
        }
      }
    },
    yAxis: {
	    min: 0,
	    max: 100,
	    gridLineColor: '#cccccc',
      gridLineDashStyle: 'dot',
	    title: {
	      text: 'Percentage %',
	      align: 'high',
	      style: {
          font: 'normal 11px Helvetica Neue, sans-serif'
        }
	    },
	    labels: {
	      overflow: 'justify'
	    }
    },
    tooltip: {
      style: {
        font: 'normal 11px Helvetica Neue, sans-serif',
        padding: 5
      },
      formatter: this.pareto_tooltip_formatter
    },
    plotOptions: {
      bar: {
        dataLabels: {
          enabled: true,
          style: {
            font: 'normal 11px Helvetica Neue, sans-serif'
          },
          overflow: 'justify',
          formatter: this.pareto_label_formatter,
          align: 'left',
          y: 0
        },
        animation: opts['isPDF'] ? false : true
      },
      series: {
        groupPadding: 0.025,
        pointWidth: 15,
        shadow: false
      }
    },
    series: [{data: opts['chartData']}],
    legend: {
      enabled:false
    }

	});
}
pare_to_chart.prototype = new adv_grid_report;
pare_to_chart.constructor = pare_to_chart;

pare_to_chart.prototype.pareToGraph = function(){
    var chart = new Highcharts.Chart(this.options);
}

function bar_chart(opts){
  adv_grid_report.call(this,{
    chart: {
      renderTo: opts['renderTo'],
      type: 'bar',
      margin: [30,10,50,80],
      borderColor: 'rgba(0,0,0,0)',
      height: (opts['chartData'].length*20 < 320)? 320 : opts['chartData'].length*20,
      width:opts['isPDF'] ? 400 : 460,
      plotBackgroundColor: 'rgba(255,255,255,0.1)',
      backgroundColor: 'rgba(255,255,255,0.1)'
    },
    title: {
      text: (typeof opts['title'] === 'undefined') ? '' : opts['title'],
      style: {fontSize: '12px'}
    },
    xAxis: {
      gridLineColor: '#197F07',
      categories: opts['xaxis_arr'],
      tickWidth: 0,
      labels: {
        formatter: this.bar_dataLabels_tooltip,
        style: {
          font: 'normal 11px Helvetica Neue, sans-serif',
          width: '50px'
        },
        useHTML: true
      }
    },
    yAxis: {
      min: 0,
      gridLineColor: '#cccccc',
      gridLineDashStyle: 'dot',
      title: {
        text: (typeof opts['yAxis_label'] === 'undefined') ? 'No. of Tickets' : opts['yAxis_label'],
        align: 'high',
        style: {
          font: 'normal 11px Helvetica Neue, sans-serif'
        }
      },
      labels: {
        overflow: 'justify'
      }
    },
    tooltip: {
      style: {
        font: 'normal 11px Helvetica Neue, sans-serif',
        padding: 5
      },
      formatter: this.barGraph_tooltip_formatter
    },
    plotOptions: {
      bar: {
        dataLabels: {
          enabled: !!opts['isPDF'],
          style: {
            font: 'normal 11px Helvetica Neue, sans-serif',
            color: 'white'
          },
          overflow: 'justify',
          align: 'left',
          y: 0,
          x: -50
        },
        animation: opts['isPDF'] ? false : true
      },
      series: {
        groupPadding: 0.025,
        pointWidth: 30,
        shadow: false
      }
    },
    series: [{data: opts['chartData']}],
    legend: {
      enabled:false
    }
  });
}
bar_chart.prototype = new adv_grid_report;
bar_chart.constructor = bar_chart;

bar_chart.prototype.barGraph = function(){
    var chart = new Highcharts.Chart(this.options);
}

function xaxis_bar_chart(opts){
  adv_grid_report.call(this,{
    chart:{
      renderTo: opts['renderTo'],
      type: 'column',
      margin: [30,10,80,80],
      borderColor: 'rgba(0,0,0,0)',
      height: (opts['chartData'].length*20 < 320)? 320 : opts['chartData'].length*20,
      plotBackgroundColor: 'rgba(255,255,255,0.1)',
      backgroundColor: 'rgba(255,255,255,0.1)'
    },
    title: {
      text: (typeof opts['title'] === 'undefined') ? '' : opts['title'],
      style: {fontSize: '12px'}
    },
    xAxis: {
      categories:opts['xAxisLabel'],
      labels: {
        style: {
          font: 'normal 11px Helvetica Neue, sans-serif'
        }
      }
    },
    yAxis: {
      min: 0,
      gridLineColor: '#cccccc',
      gridLineDashStyle: 'dot',
      title: {
        text: (typeof opts['yAxis_label'] === 'undefined') ? 'No. of Tickets' : opts['yAxis_label'],
        align: 'high',
        style: {
          font: 'normal 11px Helvetica Neue, sans-serif'
        }
      },
      labels: {
        overflow: 'justify'
      }
    },
    plotOptions: {
      column: {
        borderWidth:0,
        dataLabels: {
          enabled: !!opts['isPDF'],
          style: {
            font: 'normal 11px Helvetica Neue, sans-serif'
          },
          overflow: 'justify',
          align: 'left',
          y: 0,
          formatter: this.xaxis_bar_dataLabels
        },
        animation: opts['isPDF'] ? false : true
      },
      series: {
        shadow: false
      }
    },
    tooltip: {
      style: {
        font: 'normal 11px Helvetica Neue, sans-serif',
        padding: 5
      },
      formatter: this.xAxisGraph_tooltip_formatter
    },
    series: opts['chartData'],
    legend: {
      itemStyle: {
        fontFamily:'"Helvetica Neue", Helvetica, Arial'
      },
      style: {
        bottom: 0,
        top: 'auto',
        fontWeight: 'normal'
      },
      y: 13,
      verticalAlign: 'bottom',
      floating: false
    }
  });
}
xaxis_bar_chart.prototype = new adv_grid_report;
xaxis_bar_chart.constructor = xaxis_bar_chart;

xaxis_bar_chart.prototype.xaxisbarGraph = function(){
    var chart = new Highcharts.Chart(this.options);
}
