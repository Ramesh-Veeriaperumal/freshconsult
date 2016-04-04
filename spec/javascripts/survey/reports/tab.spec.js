jQuery.getScript("http://localhost:3000/packages/survey_report.jst").done(function(script){
	var head= document.getElementsByTagName('head')[0];
	var script = document.createElement('script');
	script.type = 'text/javascript';
	script.src = 'public/javascripts/survey/reports/tab.js';
	head.appendChild(script);
	var mockJson = document.createElement('script');
	mockJson.type = 'text/javascript';
 	mockJson.src = 'spec/javascripts/survey/reports/mockData.js';
   	head.appendChild(mockJson);	
});

describe("Report tab events",function(){
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

		var survey_report_main_content_div= jQuery("<div/>",{id:"survey_report_main_content"}).appendTo(layout_div);
		//tabs
		var tabDiv = jQuery('<div/>',{"class":'tabbable tabs-left tabs survey'}).appendTo('div#survey_report_main_content');
		var ulDiv = jQuery('<ul/>',{"class":'nav nav-tabs'}).appendTo(tabDiv);
		var li1Div = jQuery('<li/>',{'class':'nav-survey-rating active','id':'3_rating','data-type':'rating','data-id':'3'}).appendTo(ulDiv);
		var li2Div = jQuery('<li/>',{'class':'nav-survey-rating','id':'1_question','data-type':'question','data-id':'1'}).appendTo(ulDiv);
		var li3Div = jQuery('<li/>',{'class':'nav-survey-rating','id':'2_question','data-type':'question','data-id':'2'}).appendTo(ulDiv);		
	});
	it("should define essential properties of survey tabs",function(){
		expect(SurveyTab).toBeDefined();
		expect(SurveyTab.inactivate).toBeDefined();
		expect(SurveyTab.activate).toBeDefined();
		expect(SurveyTab.inactivateAll).toBeDefined();
		expect(SurveyTab.change).toBeDefined();
		expect(SurveyTab.data).toBeDefined();
		expect(SurveyTab.format).toBeDefined();
		expect(SurveyTab.isRequired).toBeDefined();
	});

	it("should inactivate all tabs",function(){
	
		spyOn(SurveyTab,"inactivateAll").and.callThrough();
		spyOn(SurveyTab,"inactivate");
		SurveyTab.inactivateAll();
		expect(SurveyTab.inactivate).toHaveBeenCalledWith(jQuery(jQuery(".nav-survey-rating")[0]));
	});

	it("should activate tab",function(){
		SurveyTab.activate(jQuery(jQuery(".nav-survey-rating")[1]));
		expect(jQuery(jQuery(".nav-survey-rating")[1])[0].className).toMatch("active");
	});

	it("should inactivate tab",function(){
		SurveyTab.inactivate(jQuery(jQuery(".nav-survey-rating")[0]));
		expect(jQuery(jQuery(".nav-survey-rating")[0])[0].className).toMatch("inactive");
	});

	it("should form data",function(){
		var tabs = SurveyTab.data();
		expect(tabs).not.toBe(null);
		expect(tabs).toBeDefined();
		expect(typeof(tabs)).toBe("object");
		expect(tabs[0].happy).toBeDefined();
		expect(tabs[0].neutral).toBeDefined();
		expect(tabs[0].overallStatus).toBeDefined();
		expect(tabs[0].unhappy).toBeDefined();
		expect(tabs[0].id).toBeDefined();
		expect(tabs[0].type).toBeDefined();
		expect(tabs[0].state).toBeDefined();
	});

	/*it("should change tab",function(){
		SurveyTab.change(jQuery(jQuery(".nav-survey-rating")[1]).data('id'),jQuery(jQuery(".nav-survey-rating")[1]).data('type'));
	});*/

	it("should format data",function(){
		var survey = SurveyUtil.whichSurvey();
		var reportData = SurveyReportData.reportsList;
        reportData.id = survey.id;
		var tab = SurveyTab.format(data);
		expect(tab).not.toBe(null);
		expect(tab).toBeDefined();
		expect(typeof(tab)).toBe("object");
		expect(tab.happy).toBeDefined();
		expect(tab.neutral).toBeDefined();
		expect(tab.overallStatus).toBeDefined();
		expect(tab.unhappy).toBeDefined();
	});

	it("should check if the question exists",function(){
		var isQuestion = SurveyTab.isRequired();
		expect(isQuestion).not.toBe(null);
		expect(isQuestion).toBeDefined();
		expect(isQuestion).toBeTruthy();
	});

	afterEach(function(){
		jQuery("div.pagearea").remove();
	});

});