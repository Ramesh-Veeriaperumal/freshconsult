jQuery.getScript("http://localhost:3000/packages/survey_admin.jst").done(function(script){
	var head= document.getElementsByTagName('head')[0];
	var script= document.createElement('script');
	script.type= 'text/javascript';
	script.src= 'public/javascripts/survey/admin/status.js';
	var I18nScript = document.createElement('script');
	I18nScript.type= 'text/javascript';
	I18nScript.src= 'spec/javascripts/survey/admin/I18n.js';
	head.appendChild(script);
	head.appendChild(I18nScript);
});


describe("Survey State Events",function(){

	beforeEach(function(){

	surveyData = {
  		"survey":{"account_id":2,"active":0,"can_comment":1,
				  "created_at":"2015-05-04T16:25:04+05:30","feedback_response_text":"Thank you. Your feedback has been sent.",
				  "happy_text":"Awesome","id":2,"link_text":null,
				  "neutral_text":"Just Okay","send_while":2,"thanks_text":"Thank you very much for your feedback.",
				  "title_text":"Default Survey","unhappy_text":"Not Good","updated_at":"2015-05-05T16:25:06+05:30"}
		}
	});

	it("should define essential properties of survey admin status",function(){
		expect(SurveyStatus).toBeDefined();
		expect(SurveyStatus.change).toBeDefined();
		expect(SurveyStatus.enable).toBeDefined();
		expect(SurveyStatus.disable).toBeDefined();
		expect(SurveyStatus.update).toBeDefined();
	});

	it("should enable survey",function(){
		var id = surveyData.survey.id;
		spyOn(jQuery, "ajax").and.callFake(function(options) {
	        options.success();
	    });
	    var callback = jasmine.createSpy();
	  	jQuery.ajax({
			url: "surveys/enable/"+id,
			type: "POST",
			data: {},
			success: callback
		});
		expect(jQuery.ajax.calls.mostRecent().args[0]["url"]).toEqual("surveys/enable/"+id);
	});

	it("should disable survey",function(){
		var id = surveyData.survey.id;
		spyOn(jQuery, "ajax").and.callFake(function(options) {
	        options.success();
	    });
	    var callback = jasmine.createSpy();
	  	jQuery.ajax({
			url: "surveys/disable/"+id,
			type: "POST",
			data: {},
			success: callback
		});
		expect(jQuery.ajax.calls.mostRecent().args[0]["url"]).toEqual("surveys/disable/"+id);
		expect(callback).toHaveBeenCalled();
	});

	it("should change status with disable as status",function(){
		var id = surveyData.survey.id;
		spyOn(SurveyStatus,"change").and.callThrough();
		spyOn(SurveyStatus,"disable");
		SurveyStatus.change(id,false);
		expect(SurveyStatus.change).toHaveBeenCalledWith(id,false);
		expect(SurveyStatus.disable).toHaveBeenCalledWith(id);
	});

	it("should change status with enable as status",function(){
		var id = surveyData.survey.id;
		spyOn(SurveyStatus,"change").and.callThrough();
		spyOn(SurveyStatus,"enable");
		SurveyStatus.change(id,true);
		expect(SurveyStatus.change).toHaveBeenCalledWith(id,true);
		expect(SurveyStatus.enable).toHaveBeenCalledWith(id);
	});
});