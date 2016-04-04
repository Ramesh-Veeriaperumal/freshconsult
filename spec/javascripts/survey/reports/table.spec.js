jQuery.getScript("http://localhost:3000/packages/survey_report.jst").done(function(script){
	var head= document.getElementsByTagName('head')[0];
	var script = document.createElement('script');
	script.type = 'text/javascript';
	script.src = 'public/javascripts/survey/reports/table.js';
	head.appendChild(script);
});


describe("Report table events",function(){
	beforeEach(function(){
		var pageAreaObj = jQuery("<div/>",{class:"pagearea",id:'Pagearea'}).appendTo('body');
		var layout_div = jQuery("<div/>",{id:"survey_main_layout"}).appendTo(".pagearea"); 
		var survey_report_main_content_div= jQuery("<div/>",{id:"survey_report_main_content"}).appendTo(layout_div);

		var tabDiv = jQuery('<div/>',{"class":'tabbable tabs-left tabs survey'}).appendTo('div#survey_report_main_content');
		var ulDiv = jQuery('<ul/>',{"class":'nav nav-tabs'}).appendTo(tabDiv);
		var li1Div = jQuery('<li/>',{'class':'nav-survey-rating active','id':'3_rating','data-type':'rating','data-id':'3'}).appendTo(ulDiv);
		var li2Div = jQuery('<li/>',{'class':'nav-survey-rating','id':'1_question','data-type':'question','data-id':'1'}).appendTo(ulDiv);
		var li3Div = jQuery('<li/>',{'class':'nav-survey-rating','id':'2_question','data-type':'question','data-id':'2'}).appendTo(ulDiv);		
	});

	it("should define essential properties of a table",function(){
		expect(SurveyTable).toBeDefined();
		expect(SurveyTable.notRequired).toBeDefined();
		expect(SurveyTable.reset).toBeDefined();
		expect(SurveyTable.whichReport).toBeDefined();
		expect(SurveyTable.whichChoices).toBeDefined();
		expect(SurveyTable.format).toBeDefined();
		expect(SurveyTable.draw).toBeDefined();
		expect(SurveyTable.type).toBeDefined();
		expect(SurveyTable.type.get).toBeDefined();
		expect(SurveyTable.type.change).toBeDefined();
		expect(SurveyTable.type.hide).toBeDefined();
		expect(SurveyTable.type.filter).toBeDefined();
	});

	it("should reset table details",function(){
		spyOn(SurveyTable,"reset");
		SurveyTable.reset();
		expect(SurveyTable.reset).toHaveBeenCalled();
	});

	it("should return choices",function(){
		var choices = SurveyTable.whichChoices(jQuery(jQuery(".nav-survey-rating")[1]).data('id'));
		expect(choices).not.toBe(null);
		expect(choices).toBeDefined();
	});	

	it("should format the table",function(){
		var format = SurveyTable.format(jQuery(jQuery(".nav-survey-rating")[1]).data('type'),jQuery(jQuery(".nav-survey-rating")[1]).data('id'));
		expect(format).not.toBe(null);
		expect(format).toBeDefined();
	});

	afterEach(function(){
		jQuery("div.pagearea").remove();
	});
});