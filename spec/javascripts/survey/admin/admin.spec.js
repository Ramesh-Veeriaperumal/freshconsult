jQuery.getScript("http://localhost:3000/packages/survey_admin.jst").done(function(script){
	var head= document.getElementsByTagName('head')[0];
	var script= document.createElement('script');
	script.type= 'text/javascript';
	script.src= 'public/javascripts/survey/admin.js';
	head.appendChild(script);
	var I18nScript = document.createElement('script');
	I18nScript.type= 'text/javascript';
	I18nScript.src= 'spec/javascripts/survey/admin/I18n.js';
	head.appendChild(I18nScript);
	var script= document.createElement('script');
	script.src= 'public/javascripts/survey/admin/detail.js';
	head.appendChild(script);
	var script= document.createElement('script');
	script.src= 'public/javascripts/survey/admin/validate.js';
	head.appendChild(script);
	var script= document.createElement('script');
	script.src= 'public/javascripts/survey/admin/list.js';
	head.appendChild(script);

});

describe("Survey Admin Events",function(){
	it("should define essential properties of survey admin",function(){
		expect(SurveyAdmin).toBeDefined();
		expect(SurveyAdmin.path).toBeDefined();
		expect(SurveyAdmin.render).toBeDefined();
		expect(SurveyAdmin.list).toBeDefined();
		expect(SurveyAdmin.new).toBeDefined();
		expect(SurveyAdmin.new.link).toBeDefined();
		expect(SurveyAdmin.new.link.show).toBeDefined();
		expect(SurveyAdmin.new.link.hide).toBeDefined();
		expect(SurveyAdmin.new.show).toBeDefined();
		expect(SurveyAdmin.new.remove).toBeDefined();
		expect(SurveyAdmin.edit).toBeDefined();
	});

	it("should render view",function(){
		spyOn(SurveyAdmin,"render").and.callThrough();
		spyOn(SurveyDetail.rating,"create");
		spyOn(SurveyDetail.thanks,"create");
		spyOn(SurveyValidate,"initialize");
		SurveyAdmin.render(view);
		expect(SurveyDetail.rating.create).toHaveBeenCalledWith(view);
		expect(SurveyDetail.thanks.create).toHaveBeenCalledWith(view);
		expect(SurveyValidate.initialize).toHaveBeenCalled();
	});
});