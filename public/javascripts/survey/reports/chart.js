/*
  Module deals with chart related activities.
*/
var SurveyChart = {
	create:function(chartRef){
		this.currentChart = (new Highcharts.Chart(this.data(chartRef)));
	},
	data: function(ref){   
        var choices = ref.choices;
        var ratings = ref.rating;
        var protocol = {};
        var series = [];
        var categories = [];
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
                    color: SurveyReportData.customerRatingsColor[key]
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
              labels: {
                  enabled: true
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
                pointWidth: 20,
								borderWidth: 0,
								shadow: false
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
                      return ("<b>"+this.x+" : "+this.y+"</b>");
                  },
                  style: { padding: 5 }
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