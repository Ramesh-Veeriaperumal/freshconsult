jQuery.getScript("http://localhost:3000/packages/survey_report.jst").done(function(script){
	var head= document.getElementsByTagName('head')[0];
	var script= document.createElement('script');
	script.type= 'text/javascript';
	script.src = 'public/javascripts/survey/reports/chart.js';
	head.appendChild(script);
	var highchartsScript = document.createElement('script');
	highchartsScript.type= 'text/javascript';
	highchartsScript.src= 'public/javascripts/highcharts-2.1.9.js';
	head.appendChild(highchartsScript);
	var mockJson = document.createElement('script');
	mockJson.type = 'text/javascript';
 	mockJson.src = 'spec/javascripts/survey/reports/mockData.js';
   	head.appendChild(mockJson);	
});

describe("Report chart events",function(){
	beforeEach(function(){
		var pageAreaObj = jQuery("<div/>",{class:"pagearea",id:'Pagearea'}).appendTo('body');

		chartData = {"active":1,"created_at":"2015-01-27T17:00:16+05:30","id":3,"link_text":" Please tell us what you think of your support experience","title_text":"test1",
		"choices":[["Strongly Agree", 3], ["Neutral", 0], ["Strongly Disagree", -3]],
		"survey_questions":[{"id": 1, "label": "q1", "name": "cf_q1", 
		"choices": [["Strongly Agree", 3], ["Neutral", 0], ["Strongly Disagree", -3]], 
		"rating": {"0": 10, "-3": 6}}, {"id": 2, "label": "q2", "name": "cf_q2", 
		"choices": [["Strongly Agree", 3], ["Neutral", 0], ["Strongly Disagree", -3]], 
		"rating": {"0": 3, "3": 2, "-3": 11}}, {"id": 3, "label": "q3", "name": "cf_q3", 
		"choices": [["Strongly Agree", 3], ["Neutral", 0], ["Strongly Disagree", -3]], 
		"rating": {"0": 7, "3": 6, "-3": 3}}],
		"rating":{"0":5,"3":5,"-3":6}}
	});

	it("should define essential properties of chart",function(){
		expect(SurveyChart).toBeDefined();
		expect(SurveyChart.create).toBeDefined();
		expect(SurveyChart.data).toBeDefined();
		expect(SurveyChart.options).toBeDefined();
		expect(SurveyChart.options.chart).toBeDefined();
		expect(SurveyChart.options.title).toBeDefined();
		expect(SurveyChart.options.xAxis).toBeDefined();
		expect(SurveyChart.options.yAxis).toBeDefined();
		expect(SurveyChart.options.plotOptions).toBeDefined();
		expect(SurveyChart.options.legend).toBeDefined();
		expect(SurveyChart.options.credits).toBeDefined();
		expect(SurveyChart.options.tooltip).toBeDefined();
		expect(SurveyChart.options.series).toBeDefined();
	});

	it("should form chart",function(){
		var options = SurveyChart.data(chartData);
		expect(options).not.toBe(null);
		expect(options).toBeDefined();
		expect(typeof(options)).toBe("object");
		expect(options.chart).toBeDefined();
		expect(options.credits).toBeDefined();
		expect(options.legend).toBeDefined();
		expect(options.plotOptions).toBeDefined();
		expect(options.series).toBeDefined();
		expect(options.title).toBeDefined();
		expect(options.tooltip).toBeDefined();
		expect(options.xAxis).toBeDefined();
		expect(options.yAxis).toBeDefined();
	});

	afterEach(function(){
		jQuery("div.pagearea").remove();
	})
});
