jQuery.getScript("http://localhost:3000/packages/survey_report.jst").done(function(script){
	var head= document.getElementsByTagName('head')[0];
	var script = document.createElement('script');
	script.type = 'text/javascript';
	script.src = 'public/javascripts/survey/reports/list.js';
	head.appendChild(script);
	var mockJson = document.createElement('script');
	mockJson.type = 'text/javascript';
 	mockJson.src = 'spec/javascripts/survey/reports/mockData.js';
   	head.appendChild(mockJson);	
});

describe("Report list events",function(){

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

	});

	it("should define essential properties of survey report lists",function(){
		expect(SurveyList).toBeDefined();
		expect(SurveyList.change).toBeDefined();
	});

	it("should trigger change function on changing surveylist",function(){
		spyOn(jQuery, "ajax").and.callFake(function(options) {
			options.success();
        });
        var timestamp = SurveyDateRange.convertDateToTimestamp('6 Apr, 2015 - 6 May, 2015');
	    var callback = jasmine.createSpy();
        jQuery.ajax({
            type: 'GET',
            url: '/survey/reports/'+jQuery("#survey_report_survey_list").val()+"/"+
            	 jQuery("#survey_report_group_list").val() + "/" + jQuery("#survey_report_agent_list").val()
            	 +"/" +timestamp,
            success: callback
        });
        expect(callback).toHaveBeenCalled();
	});

	afterEach(function(){
		jQuery("div.pagearea").remove();
	});
});
