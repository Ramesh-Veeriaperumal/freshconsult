jQuery.getScript("http://localhost:3000/packages/survey_admin.jst").done(function(script){
	var head= document.getElementsByTagName('head')[0];
	var script= document.createElement('script');
	script.type= 'text/javascript';
	script.src= 'public/javascripts/survey/admin/detail.js';
	head.appendChild(script);
	var I18nScript = document.createElement('script');
	I18nScript.type= 'text/javascript';
	I18nScript.src= 'spec/javascripts/survey/admin/I18n.js';
	head.appendChild(I18nScript);
});

describe("Survey Detail events",function(){
	it("should describe essential properties of survey details",function(){
		expect(SurveyDetail).toBeDefined();
		expect(SurveyDetail.preview).toBeDefined();
		expect(SurveyDetail.parseFormData).toBeDefined();
		expect(SurveyDetail.rating).toBeDefined();
		expect(SurveyDetail.rating.create).toBeDefined();
		expect(SurveyDetail.thanks).toBeDefined();
		expect(SurveyDetail.thanks.create).toBeDefined();
	});

	/*it("should show a preview of survey feedback",function(){
		spyOn(SurveyDetail,'preview');
		expect(SurveyDetail.preview).toHaveBeenCalled();
		/*spyOn(jQuery, "ajax").andCallFake(function(options) {
			options.beforeSend();
          	expect(SurveyList.Preview).toHaveBeenCalled();
        });
	});*/

	afterEach(function(){
		jQuery("div.pagearea").remove();
		jQuery("div#survey_thanks").remove();
	});	
});