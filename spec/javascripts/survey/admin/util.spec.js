jQuery.getScript("http://localhost:3000/packages/survey_admin.jst").done(function(script){
	var head= document.getElementsByTagName('head')[0];
	var script= document.createElement('script');
	script.type= 'text/javascript';
	script.src= 'public/javascripts/survey/admin/util.js';
	var I18nScript = document.createElement('script');
	I18nScript.type= 'text/javascript';
	I18nScript.src= 'spec/javascripts/survey/admin/I18n.js';
	head.appendChild(script);
	head.appendChild(I18nScript);
});


describe("Survey Util events",function(){
	it("should define essential properties of survey admin util",function(){
		expect(SurveyAdminUtil.blockUI).toBeDefined();
		expect(SurveyAdminUtil.unblockUI).toBeDefined();
		expect(SurveyAdminUtil.action).toBeDefined();
		expect(SurveyAdminUtil.action.split).toBeDefined();
		expect(SurveyAdminUtil.makeURL).toBeDefined();
	});

	it("should split action",function(){
		var action  = view.action;
		action = SurveyAdminUtil.action.split(action);
		expect(action).not.toBe(undefined);
		expect(action.length).toBeGreaterThan(0);
	});

	it("should block UI",function(){
		var msg = 'test msg';
		SurveyAdminUtil.blockUI(msg);
		expect(jQuery('.blockUI.blockOverlay')).toBeDefined();
		expect(jQuery('.blockUI.blockMsg')).toBeDefined();
		expect(jQuery(".blockUI.blockMsg").text()).toEqual(msg);
		SurveyAdminUtil.unblockUI();
	});
	it("should unblock UI",function(){
		SurveyAdminUtil.unblockUI();
		expect(jQuery('.blockUI.blockMsg').length).toBeGreaterThan(0);
	});
});