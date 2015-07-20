jQuery.getScript("http://localhost:3000/packages/survey_admin.jst").done(function(script){
	var head= document.getElementsByTagName('head')[0];
	var script= document.createElement('script');
	script.type= 'text/javascript';
	script.src= 'public/javascripts/survey/feedback.js';
	head.appendChild(script);
});


describe("Feedback events", function(){
	it("should describe feedback events",function(){
		expect(Feedback).toBeDefined();
		expect(Feedback.submit).toBeDefined();
		expect(Feedback.fetch).toBeDefined();
		expect(Feedback.showGreyScreen).toBeDefined();
		expect(Feedback.hideGreyScreen).toBeDefined();
		expect(Feedback.hide).toBeDefined();

	});

	it("should submit a feedback",function(){
		var action = "surveys/16ea7533fdb8a83d44d91d74c23cd813/0";
		spyOn(jQuery, "ajax").and.callFake(function(options) {
	        options.success();
	    });
	    var callback = jasmine.createSpy();
    	var data = {"custom_field": {"cf_thank_you_for_valuable_feedback" : 0}};
	  	jQuery.ajax({
			url: action,
			type: "POST",
			data: data,
			success: callback
		});
		expect(callback).toHaveBeenCalled();
	});
});