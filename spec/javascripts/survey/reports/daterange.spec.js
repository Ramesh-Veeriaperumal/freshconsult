jQuery.getScript("http://localhost:3000/packages/survey_report.jst").done(function(script){
	var head= document.getElementsByTagName('head')[0];
	var script = document.createElement('script');
	script.type = 'text/javascript';
	script.src = 'public/javascripts/survey/reports/daterange.js';
	head.appendChild(script);
});

describe("Report date range events",function(){
	beforeEach(function(){
		var pageAreaObj = jQuery("<div/>",{class:"pagearea",id:'Pagearea'}).appendTo('body');
		var layout_div = jQuery("<div/>",{id:"survey_main_layout"}).appendTo(".pagearea"); 

		//date-range div
		var date_div = jQuery("<div/>",{id:"survey_date_link_container"}).appendTo('body');
		var date_link = jQuery("<a/>",{id: "survey_date_range_link",text:"4 Dec, 2014 - 3 Jan, 2015", value:"4 Dec, 2014 - 3 Jan, 2015"});
		date_link.appendTo(date_div);
		date_div.appendTo(layout_div);

		var survey_report_main_content_div= jQuery("<div/>",{id:"survey_report_main_content"}).appendTo(layout_div);
	});

	it("should define essential properties of survey date range",function(){
		expect(SurveyDateRange).toBeDefined();
		expect(SurveyDateRange.isInitialized).toBeDefined();
		expect(SurveyDateRange.init).toBeDefined();
		expect(SurveyDateRange.open).toBeDefined();
		expect(SurveyDateRange.close).toBeDefined();
	});

	afterEach(function(){
		jQuery("div.pagearea").remove();
	});
});