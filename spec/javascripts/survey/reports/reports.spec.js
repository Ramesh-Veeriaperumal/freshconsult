var SurveyI18N = {};
SurveyI18N.all = 'All';

jQuery.getScript("http://localhost:3000/packages/survey_report.jst").done(function(script){
	var head= document.getElementsByTagName('head')[0];
	var mockJson = document.createElement('script');
	mockJson.type = 'text/javascript';
 	mockJson.src = 'spec/javascripts/survey/reports/mockData.js';
   	head.appendChild(mockJson);
   	var script= document.createElement('script');
	script.type= 'text/javascript';
	script.src= 'public/javascripts/survey/reports/util.js';
	head.appendChild(script);
	var script= document.createElement('script');
	script.type= 'text/javascript';
	script.src= 'public/javascripts/survey/reports/daterange.js';
	head.appendChild(script);	
	var script= document.createElement('script');
	script.type= 'text/javascript';
	script.src= 'public/javascripts/survey/reports/state.js';
	head.appendChild(script);	
	var script= document.createElement('script');
	script.type= 'text/javascript';
	script.src= 'public/javascripts/survey/report.js';
	head.appendChild(script);
});

describe("Report events",function(){
	beforeEach(function(){
		var pageAreaObj = jQuery("<div/>",{class:"pagearea",id:'Pagearea'}).appendTo('body');
		var layout_div = jQuery("<div/>",{id:"survey_main_layout"}).appendTo(".pagearea"); 
		//Survey lists div
		var select_div = jQuery("<select/>",{id:"survey_report_survey_list"}).appendTo(layout_div);
		var options_div = jQuery("<option/>",{value:"2", text:"Default Survey"}).appendTo(select_div);
		var options_div1 = jQuery("<option/>",{value:"4",text:" ewrwerwer "}).appendTo(select_div);
		var options_div2 = jQuery("<option/>",{value:"3",text:" test ", selected: true}).appendTo(select_div);
		//Group div
		var group_div = jQuery("<select/>",{id:"survey_report_group_list"}).appendTo(layout_div);
		var options_div = jQuery("<option/>",{value:"all", text:"All"}).appendTo(group_div);
		var options_div1 = jQuery("<option/>",{value:"4", text:"Product Management"}).appendTo(group_div);
		var options_div2 = jQuery("<option/>",{value:"5", text:"QA"}).appendTo(group_div);
		var options_div3 = jQuery("<option/>",{value:"6", text:"Sales"}).appendTo(group_div);
		//Agent div
		var agent_div = jQuery("<select/>",{id:"survey_report_agent_list"}).appendTo(layout_div);
		var options_div = jQuery("<option/>",{value:"all", text:"All"}).appendTo(agent_div);
		var options_div1 = jQuery("<option/>",{value:"3", text:"Support"}).appendTo(agent_div);

		//date-range div
		var date_div = jQuery("<div/>",{id:"survey_date_link_container"}).appendTo('body');
		var date_link = jQuery("<a/>",{id: "survey_date_range_link",text:"4 Dec, 2014 - 3 Jan, 2015", value:"4 Dec, 2014 - 3 Jan, 2015"});
		date_link.appendTo(date_div);
		date_div.appendTo(layout_div);

		var survey_report_main_content_div= jQuery("<div/>",{id:"survey_report_main_content"}).appendTo(layout_div);
	});

	it("should define essential properties of survey report",function(){
		expect(SurveyReport).toBeDefined();
		expect(SurveyDropDown).toBeDefined();
		expect(SurveyReport.init).toBeDefined();
		expect(SurveyReport.isEmptyChart).toBeDefined();
		expect(SurveyReport.hideReport).toBeDefined();
		expect(SurveyReport.showReport).toBeDefined();
		expect(SurveyDropDown.rating).toBeDefined();
	});



	it("should call the init function of survey reports",function(){
		spyOn(SurveyReport,"init").and.callThrough();
		spyOn(SurveyUtil,"mapResults");
		spyOn(SurveyUtil,"reverseChoices");
		spyOn(SurveyDateRange,"init");
		spyOn(SurveyState,"init");
		SurveyReport.init();
		expect(SurveyUtil.mapResults).toHaveBeenCalled();
		expect(SurveyUtil.reverseChoices).toHaveBeenCalled();
		expect(SurveyDateRange.init).toHaveBeenCalled();
		expect(SurveyState.init).toHaveBeenCalled();
	});

	afterEach(function(){
		jQuery("div.pagearea").remove();
	});
});
