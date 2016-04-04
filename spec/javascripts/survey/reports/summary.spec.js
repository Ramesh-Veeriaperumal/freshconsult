jQuery.getScript("http://localhost:3000/packages/survey_report.jst").done(function(script){
	var head= document.getElementsByTagName('head')[0];
	var script = document.createElement('script');
	script.type = 'text/javascript';
	script.src = 'public/javascripts/survey/reports/summary.js';
	head.appendChild(script);
	var mockJson = document.createElement('script');
	mockJson.type = 'text/javascript';
 	mockJson.src = 'spec/javascripts/survey/reports/mockData.js';
   	head.appendChild(mockJson);	
});

describe("Report summary events",function(){

	beforeEach(function(){
		var pageAreaObj = jQuery("<div/>",{class:"pagearea",id:'Pagearea'}).appendTo('body');
		var layout_div = jQuery("<div/>",{id:"survey_main_layout"}).appendTo(".pagearea"); 
		var survey_report_main_content_div= jQuery("<div/>",{id:"survey_report_main_content"}).appendTo(layout_div);
		var tabDiv = jQuery('<div/>',{"class":'tabbable tabs-left tabs survey'}).appendTo('div#survey_report_main_content');
		var ulDiv = jQuery('<ul/>',{"class":'nav nav-tabs'}).appendTo(tabDiv);
		var li1Div = jQuery('<li/>',{'class':'nav-survey-rating active','id':'3_rating','data-type':'rating','data-id':'3'}).appendTo(ulDiv);
		var li2Div = jQuery('<li/>',{'class':'nav-survey-rating','id':'1_question','data-type':'question','data-id':'1'}).appendTo(ulDiv);
		var li3Div = jQuery('<li/>',{'class':'nav-survey-rating','id':'2_question','data-type':'question','data-id':'2'}).appendTo(ulDiv);	

		var select_div = jQuery("<select/>",{id:"survey_report_filter_by"}).appendTo(layout_div);
		var options_div = jQuery("<option/>",{value:"-103", text:"Strongly Disagree"}).appendTo(select_div);
		var options_div1 = jQuery("<option/>",{value:"100",text:"Neutral"}).appendTo(select_div);
		var options_div2 = jQuery("<option/>",{value:"103",text:"Strongly Agree",selected:true}).appendTo(select_div);	
		var options_div3 = jQuery("<option/>",{value:"a",text:"All"}).appendTo(select_div)

	});

	it("should define essential properties of summary",function(){
		expect(SurveySummary).toBeDefined();
		expect(SurveySummary.reset).toBeDefined();
		expect(SurveySummary.create).toBeDefined();
	});

	it("should reset summary",function(){
		var type = jQuery(jQuery(".nav-survey-rating")[1]).data('type');
		var id = jQuery(jQuery(".nav-survey-rating")[1]).data('id');
		spyOn(SurveySummary,"reset");
		SurveySummary.reset(type,id);
		expect(SurveySummary.reset).toHaveBeenCalledWith(type,id);
	});

	it("should create summary",function(){
		var type = jQuery(jQuery(".nav-survey-rating")[2]).data('type');
		var id = jQuery(jQuery(".nav-survey-rating")[2]).data('id');
		var protocol = SurveySummary.create(type,id);
		expect(protocol).toBeDefined();
		expect(protocol.isRatingFilter).toBeDefined();
		expect(protocol.percentile).toBeDefined();
		expect(protocol.question).toBeDefined();
		expect(protocol.ratingCount).toBeDefined();
		expect(protocol.ratingPercentage).toBeDefined();
		expect(protocol.ratingSmiley).toBeDefined();
		expect(protocol.type).toBeDefined();
	});

	it("should filter rating type",function(){
		var type = jQuery(jQuery(".nav-survey-rating")[2]).data('type');
		var filterType = SurveySummary.isRatingFilter(type);
		expect(filterType).toBeDefined();
		expect(filterType).not.toBe(null);
	});
});

