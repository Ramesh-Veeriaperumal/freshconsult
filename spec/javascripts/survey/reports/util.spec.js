jQuery.getScript("http://localhost:3000/packages/survey_report.jst").done(function(script){
	var head= document.getElementsByTagName('head')[0];
	var util = document.createElement('script');
	util.type = 'text/javascript';
	util.src = 'public/javascripts/survey/reports/util.js';
	head.appendChild(util);
	var mockJson = document.createElement('script');
	mockJson.type = 'text/javascript';
 	mockJson.src = 'spec/javascripts/survey/reports/mockData.js';
   	head.appendChild(mockJson);	
});

describe("Report util events",function(){
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

		var tabDiv = jQuery('<div/>',{"class":'tabbable tabs-left tabs survey'}).appendTo('div#survey_report_main_content');
		var ulDiv = jQuery('<ul/>',{"class":'nav nav-tabs'}).appendTo(tabDiv);
		var li1Div = jQuery('<li/>',{'class':'nav-survey-rating active','id':'3_rating','data-type':'rating','data-id':'3'}).appendTo(ulDiv);
		var li2Div = jQuery('<li/>',{'class':'nav-survey-rating','id':'1_question','data-type':'question','data-id':'1'}).appendTo(ulDiv);
		var li3Div = jQuery('<li/>',{'class':'nav-survey-rating','id':'2_question','data-type':'question','data-id':'2'}).appendTo(ulDiv);		
	});

	it("should define essential propoerties of survey util",function(){
		expect(SurveyUtil).toBeDefined();
		expect(SurveyUtil.smiley).toBeDefined();
		expect(SurveyUtil.whichSurvey).toBeDefined();
		expect(SurveyUtil.reverseChoices).toBeDefined();
		expect(SurveyUtil.updateData).toBeDefined();
		expect(SurveyUtil.mapResults).toBeDefined();
		expect(SurveyUtil.mapQuestionsResult).toBeDefined();
		expect(SurveyUtil.makeURL).toBeDefined();
		expect(SurveyUtil.isQuestionsExist).toBeDefined();
		expect(SurveyUtil.findQuestionResult).toBeDefined();
		expect(SurveyUtil.findQuestion).toBeDefined();
		expect(SurveyUtil.ratingFormat).toBeDefined();
		expect(SurveyUtil.getDateString).toBeDefined();
		expect(SurveyUtil.rating).toBeDefined();
		expect(SurveyUtil.rating.choice).toBeDefined();
		expect(SurveyUtil.rating.arrayToHash).toBeDefined();
		expect(SurveyUtil.rating.style).toBeDefined();
		expect(SurveyUtil.rating.text).toBeDefined();
	});

	it("Should find out the selected survey",function(){
		var selectedSurvey = SurveyUtil.whichSurvey();
		expect(selectedSurvey).not.toBe(null);
		expect(typeof(selectedSurvey)).toBe("object");
	});

	it("Should reverse choices",function(){
		spyOn(SurveyUtil,"reverseChoices");
		SurveyUtil.reverseChoices();
		expect(SurveyUtil.reverseChoices).toHaveBeenCalled();
	});

	it("should mapResults",function(){
		spyOn(SurveyUtil, "mapResults").and.callThrough();
		spyOn(SurveyUtil, "whichSurvey");
		spyOn(SurveyUtil, "mapQuestionsResult");
		SurveyUtil.mapResults();
		expect(SurveyUtil.whichSurvey).toHaveBeenCalled();
		expect(SurveyUtil.mapQuestionsResult).toHaveBeenCalled();
	});

	it("should check if survey questions exists",function(){
		var flag = SurveyUtil.isQuestionsExist();
		expect(flag).not.toBe(null);
		expect(flag).toBeDefined();
	});

	it("should find question results",function(){
		var name = SurveyReportData.surveysList[2].survey_questions[0].name;
		var result = SurveyUtil.findQuestionResult(name);
		expect(result).toBeDefined();
	});

	it("should find question",function(){
		var question = SurveyUtil.findQuestion(jQuery(jQuery(".nav-survey-rating")[1]).data('id'));
		expect(question).toBeDefined();
		expect(question.id).toBeDefined();
		expect(question.label).toBeDefined();
		expect(question.name).toBeDefined();
		expect(question.choices).toBeDefined();
	});

	it("should return rating format",function(){
		var name = SurveyReportData.surveysList[2].survey_questions[0].name;
		var obj = SurveyUtil.findQuestionResult(name);
		var newObj = SurveyUtil.ratingFormat(obj);
		expect(newObj).toBeDefined();
		expect(newObj).not.toBe(null);
	});

	it("should return the rating key",function(){
		var rating = SurveyReportData.type.rating;
		var key= SurveyUtil.ratingKey(rating);
		expect(key).toBeDefined();
		expect(key).not.toBe(null);
	})

	it("should find smiley",function(){
		var rating = SurveyReportData.type.rating;
		var smiley = SurveyUtil.findSmiley(rating);
		expect(smiley).toBeDefined();
		expect(smiley).not.toBe(null);
	});

	it("should return consolidated percentage",function(){
		var data = SurveyUtil.whichSurvey();
		var percentile = SurveyUtil.consolidatedPercentage(data);
		expect(percentile).toBeDefined();
		expect(percentile).not.toBe(null);
		expect(percentile.happy).toBeDefined();
		expect(percentile.unhappy).toBeDefined();
		expect(percentile.neutral).toBeDefined();
		expect(percentile.happy.count).toBeDefined();
		expect(percentile.happy.percentage).toBeDefined();
		expect(percentile.happy.smiley).toBeDefined();
		expect(percentile.happy.status).toBeDefined();
		expect(percentile.unhappy.count).toBeDefined();
		expect(percentile.unhappy.percentage).toBeDefined();
		expect(percentile.unhappy.smiley).toBeDefined();
		expect(percentile.unhappy.status).toBeDefined();
		expect(percentile.neutral.count).toBeDefined();
		expect(percentile.neutral.percentage).toBeDefined();
		expect(percentile.neutral.smiley).toBeDefined();
		expect(percentile.neutral.status).toBeDefined();
	});

	afterEach(function(){
		jQuery("div.pagearea").remove();
	});

});