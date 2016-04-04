jQuery.getScript("http://localhost:3000/packages/survey_admin.jst").done(function(script){
	var head= document.getElementsByTagName('head')[0];
	var script= document.createElement('script');
	script.type= 'text/javascript';
	script.src= 'public/javascripts/survey/admin/list.js';
	head.appendChild(script);
	var I18nScript = document.createElement('script');
	I18nScript.type= 'text/javascript';
	I18nScript.src= 'spec/javascripts/survey/admin/I18n.js';
	head.appendChild(I18nScript);
});

describe("Survey List Events",function(){
		it("should define essential properties",function(){
			expect(SurveyList).toBeDefined();
			expect(SurveyList.show).toBeDefined();
			expect(SurveyList.destroy).toBeDefined();
		});


		it("should destroy survey",function(){
			var id = survey_list.survey.id;
			spyOn(jQuery, "ajax").and.callFake(function(options) {
		        options.success();
		    });
		    var callback = jasmine.createSpy();
		  	jQuery.ajax({
				url: "/admin/surveys/delete/"+id,
				type: "POST",
				data: {},
				success: callback
			});
			expect(jQuery.ajax.calls.mostRecent().args[0]["url"]).toEqual("/admin/surveys/delete/"+id);
			expect(callback).toHaveBeenCalled();
		});
});