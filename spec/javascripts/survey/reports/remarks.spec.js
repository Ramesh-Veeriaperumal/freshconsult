jQuery.getScript("http://localhost:3000/packages/survey_report.jst").done(function(script){
	var head= document.getElementsByTagName('head')[0];
	var remarks = document.createElement('script');
	remarks.type = 'text/javascript';
	remarks.src = 'public/javascripts/survey/reports/remarks.js';
	head.appendChild(remarks);
	var mockJson = document.createElement('script');
	mockJson.type = 'text/javascript';
 	mockJson.src = 'spec/javascripts/survey/reports/mockData.js';
   	head.appendChild(mockJson);	
   	var script= document.createElement('script');
	script.type= 'text/javascript';
	script.src= 'public/javascripts/survey/report.js';
	head.appendChild(script);
});

beforeEach(function(){

	data = {"remarks":[{"created_at":"2015-05-04T17:23:37+05:30","id":8,"rating":100,
				 "survey_remark":{"account_id":2,"created_at":"2015-05-04T17:27:30+05:30","id":8,"note_id":19,"survey_result_id":8,"updated_at":"2015-05-04T17:27:30+05:30",
				 "feedback":{"body":"k"}},
				 "surveyable":{"display_id":2,"subject":"hj"},
				 "customer":{"id":5,"name":"Vasuthashankar","avatar":"/assets/misc/profile_blank_thumb.gif"},
				 "agent":{"id":3,"name":"Support"},"group":{"id":5,"name":"QA"}},{"created_at":"2015-05-04T17:06:10+05:30","id":6,"rating":100,
				 "survey_remark":{"account_id":2,"created_at":"2015-05-04T17:06:38+05:30","id":6,"note_id":15,"survey_result_id":6,"updated_at":"2015-05-04T17:06:38+05:30",
				 "feedback":{"body":"jjk"}},
				 "surveyable":{"display_id":2,"subject":"hj"},
				 "customer":{"id":5,"name":"Vasuthashankar","avatar":"/assets/misc/profile_blank_thumb.gif"},
				 "agent":{"id":3,"name":"Support"},"group":{"id":5,"name":"QA"}},
				 {"created_at":"2015-05-04T16:43:11+05:30","id":3,"rating":100,"survey_remark":
				 {"account_id":2,"created_at":"2015-05-04T16:43:33+05:30","id":3,"note_id":9,"survey_result_id":3,"updated_at":"2015-05-04T16:43:33+05:30",
				 "feedback":{"body":"j"}},
				 "surveyable":{"display_id":2,"subject":"hj"},"customer":{"id":5,"name":"Vasuthashankar","avatar":"/assets/misc/profile_blank_thumb.gif"},
				 "agent":{"id":3,"name":"Support"}},{"created_at":"2015-05-04T16:30:36+05:30","id":1,"rating":100,"survey_remark":
				 {"account_id":2,"created_at":"2015-05-04T16:33:39+05:30","id":1,"note_id":5,"survey_result_id":1,"updated_at":"2015-05-04T16:33:39+05:30",
				 "feedback":{"body":"jds"}},"surveyable":{"display_id":2,"subject":"hj"},
				 "customer":{"id":5,"name":"Vasuthashankar","avatar":"/assets/misc/profile_blank_thumb.gif"},
				 "agent":{"id":3,"name":"Support"}}],
				 "total":8,"page_limit":10,"survey_report_summary":{"unanswered":0,"questions_result":
				 {"cf_how_would_you_rate_your_overall_satisfaction_for_the_resolution_provided_by_the_agent":{"rating":
				 [{"rating":-103,"total":2},{"rating":100,"total":4},{"rating":103,"total":2}],"default":true},
				 "cf_are_you_satisfied_with_our_customer_support_experience":{"rating":[{"rating":-103,"total":2},
				 {"rating":100,"total":6}],"default":false},
				 "cf_are_you_satisfied_with_our_replies":{"rating":[{"rating":-103,"total":2},{"rating":100,"total":3},{"rating":103,"total":3}],"default":false}},
				 "group_wise_report":"null","agent_wise_report":"null"}};
});

describe("Report remarks events",function(){
	it("should define essential properties of survey reamrks",function(){
		expect(SurveyRemark).toBeDefined();
		expect(SurveyRemark.currentPage).toBeDefined();
		expect(SurveyRemark.totalPages).toBeDefined();
		expect(SurveyRemark.pageLimit).toBeDefined();	
		expect(SurveyRemark.fetch).toBeDefined();
		expect(SurveyRemark.makeURL).toBeDefined();
		expect(SurveyRemark.renderContent).toBeDefined();
		expect(SurveyRemark.renderPageless).toBeDefined();
		expect(SurveyRemark.format).toBeDefined();
	});

	it("should block and unblock on changing lists",function(){
		var obj = jQuery('#survey_report_main_content');
	    spyOn(jQuery, "ajax").and.callFake(function(options) {
			options.beforeSend();
	    	expect(SurveyRemark.fetch).toHaveBeenCalled();
          	
        });
        return new jQuery.Deferred()
        var callback = jasmine.createSpy();
        sendRequest(callback, SurveyRemark.makeURL);
        expect(callback).toHaveBeenCalled();
	});


	/*it("should render content",function(){
		spyOn(SurveyRemark,"renderContent").and.callThrough();
		spyOn(SurveyRemark,"format");
		SurveyRemark.renderContent(data,false);
		expect(SurveyRemark.format).toHaveBeenCalledWith(data.remarks);
	});*/

	it("should render pageless content",function(){
		spyOn(SurveyRemark,"renderPageless").and.callThrough();
		spyOn(SurveyRemark,"renderContent");
		SurveyRemark.renderPageless(JSON.stringify(data),true);
		expect(SurveyRemark.renderContent).toHaveBeenCalled();
	});

	it("should format data",function(){
		var result = SurveyRemark.format(data.remarks);
		expect(result).toBeDefined();
		expect(result).not.toBe(null);
		expect(typeof(result)).toBe("object");
		expect(result[0].agent).toBeDefined();
		expect(result[0].customer).toBeDefined();
		expect(result[0].msg).toBeDefined();
		expect(result[0].group).toBeDefined();
		expect(result[0].rating).toBeDefined();
		expect(result[0].ticket).toBeDefined();
	});

	it("should fetch survey responses",function(){
		 spyOn(jQuery, "ajax").and.callFake(function(options) {
			options.success();
        });
        var timestamp = SurveyDateRange.convertDateToTimestamp('6 Apr, 2015 - 6 May, 2015');
	    var callback = jasmine.createSpy();
        jQuery.ajax({
            type: 'GET',
            url: '/survey/reports/'+jQuery("#survey_report_survey_list").val()+"/"+
            	 jQuery("#survey_report_group_list").val() + "/" + jQuery("#survey_report_agent_list").val()
            	 +"/a" +timestamp,
            success: callback
        });
        expect(callback).toHaveBeenCalled();
	});
});

afterEach(function(){
	jQuery("div.pagearea").remove();
});