/*
  Module deals with chart related activities.
*/
var SurveyChart = {
	create:function(chartRef){
		this.currentChart = (new Highcharts.Chart(this.data(chartRef)));
	},
	data: function(ref){   
        var total = 0;
        var choices = ref.choices;
        var ratings = ref.rating;
        var protocol = {};
        var series = [];
        var categories = [];
        for(var i=0;i<choices.length;i++){
          total += ratings[choices[i].face_value] || 0;
        }
        for(var i=0;i<choices.length;i++){
          var data = [];
          var key =  choices[i].face_value;
          var name = choices[i].value;
          for(var j=0;j<i;j++){
              data.push(0);
          }
          var rating = (ratings) ? ratings[key] : null;
          data.push(((rating) ? rating : 0));
          series.push({
              name: name,
              data: data,
              color: SurveyReportData.customerRatingsColor[key],
              percent: (rating/total)*100
          });
          categories.push(name);
        }
        this.options.series = series;
        this.options.xAxis.categories = categories;
        return this.options;
    },
    options:{
          chart: {
              renderTo: "survey_chart",
              type: 'bar',
							plotShadow: false
          },
          title:{
              text:"",
              enabled:false
          },
          xAxis: {
              categories:  [
                    'Extremely Happy', 
                    'Very Happy', 
                    'Happy', 
                    'Neutral', 
                    'Unhappy',
                    'Very Unhappy',
                    'Extremely Unhappy'
              ],
              gridLineColor: '#FFFFFF',
              gridLineWidth: 0,
              minorGridLineWidth: 0,
              tickWidth:0,
              lineWidth:0,
              offset: 15,
              labels: {
                  enabled: true,
                  y: 4,  
                  style: {
                      fontSize: '12px'
                  }
              }
          },
          yAxis: {      
            labels: {
              enabled: false
            },
            title:{
              text:null
            },
            gridLineWidth:0
          },
          plotOptions: {
              series: {
                stacking: 'normal',
                pointWidth: 10,
								borderWidth: 2,
                borderRadius: 5,
								shadow: false,
                dataLabels: {
                  enabled: true,
                  align: 'right',
                  x: 15,
                  y: -2,
                  style: {
                      fontWeight: 'bold',
                      fontSize: '12px'
                  },
                  formatter: function(){
                    return (this.y>0)? this.y : null;
                  }
                }
              }
          },
          legend: {
              layout: 'horizontal',
              align: 'center',
                  enabled:false,    
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
              verticalAlign: 'bottom',
              floating: false
          },

          credits: {
            enabled:false
          },

          tooltip: {
              formatter: function(){
                      return ('<span style="color:'+ this.series.color + '"><b>'+this.x+" : "+ Highcharts.numberFormat(this.series.options.percent,2) +'%</b></span>');
                  },
                  useHTML: true,
                  backgroundColor: '#000000',
                  borderColor: '#000000',
                  borderRadius: 0,
                  style: { 
                    padding: 5
                    
                  }
          },

          series: [
                      {
                          name: "Extremely Happy",
                          color: "#4e8d00",
                          data:[5]
                      },
                      {
                          name: "Very Happy",
                          color: "#6bb437",
                          data:[0,3]
                      },
                      {
                              name: "Happy",
                              color: "#a9d340",
                              data:[0,0,4]
                      },
                      {
                          name: "Neutral",
                          color: "#f1db15",
                          data:[0,0,0,7]
                      },
                      {
                          name: "Unhappy",
                          color: "#ffc400",
                          data:[0,0,0,0,2]
                      },
                      {
                          name: "Very Unhappy",
                          color: "darkorange",
                          data:[0,0,0,0,0,5]
                      },
                      {
                          name: "Extremely Unhappy",
                          color: "#e7340f",
                          data:[0,0,0,0,0,0,6]
                      }
                    ]
     }
}