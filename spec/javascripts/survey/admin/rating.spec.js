jQuery.getScript("http://localhost:3000/packages/survey_admin.jst").done(function(script){
	var head= document.getElementsByTagName('head')[0];
	var script= document.createElement('script');
	script.type= 'text/javascript';
	script.src= 'public/javascripts/survey/rating.js';
	head.appendChild(script);
});

describe("Rating events", function(){
	var span1Div = "";
	beforeEach(function() {
		var pageAreaObj = jQuery("<div/>",{class:"pagearea"}).appendTo('body');
		    span1Div = jQuery("<span/>",{class:"survey-rating question-rating-3 none","id":"rating_0",
					"data-class" : "strongly-disagree" , "data-id" : "3" , "data-question-id" : 3 , "data-name" : "Strongly Disagree" ,
					"onmouseover": "javascript:SurveyRating.hover(this);", 
					"onmouseout" : "javascript:SurveyRating.resetLabel(this);" ,
					"onclick" : "javascript:SurveyRating.input(this);"}).appendTo(".pagearea");
  	});

  	it("should describe rating events",function(){
  		expect(SurveyRating).toBeDefined();
  		expect(SurveyRating.state_object).toBeDefined();
  		expect(SurveyRating.input).toBeDefined();
  		expect(SurveyRating.hover).toBeDefined();
  		expect(SurveyRating.resetLabel).toBeDefined();
  		expect(SurveyRating.updateLabel).toBeDefined();
  		expect(SurveyRating.fix).toBeDefined();
  		expect(SurveyRating.clear).toBeDefined();
  	});

	it("should provide details on hover", function(){
		var id = span1Div.data('id');
		var qid = span1Div.data('question-id');
		var name = span1Div.data("name");
		var labelDiv = jQuery("<label/>",{class:"rating-label-"+qid,"id":"rating-label-3","data-selected-value" : "None", "data-selected-id": "none", "data-custom-field":"cf_thank_you_for_your_valuable_feedback"}).appendTo(".pagearea");

		spyOn(SurveyRating, "hover").and.callThrough();
		spyOn(SurveyRating, "updateLabel");
		spyOn(SurveyRating, "fix");
		spyOn(SurveyRating, "clear");
		SurveyRating.hover(span1Div);

		expect(SurveyRating.updateLabel).toHaveBeenCalledWith(id,qid,name);
		expect(SurveyRating.clear).toHaveBeenCalledWith(id);
		expect(SurveyRating.fix).toHaveBeenCalledWith(id,qid);		
		expect(jQuery("#rating-label-"+qid).data("selected-value")).toEqual("None");
		expect(jQuery("#rating-label-"+qid).data("selected-id")).toEqual("none");
	});

	it("should update labels on hover",function(){
		var id = span1Div.data('id');
		var qid = span1Div.data('question-id');
		var name = span1Div.data("name");
		var labelDiv = jQuery("<label/>",{class:"rating-label-"+qid,"id":"rating-label-3","data-selected-value" : "None", "data-selected-id": "none", "data-custom-field":"cf_thank_you_for_your_valuable_feedback"}).appendTo(".pagearea");
		SurveyRating.updateLabel(id,qid,name);

		expect(jQuery("#rating-label-"+qid).data("selected-value")).toBeDefined();
		expect(jQuery("#rating-label-"+qid).data("selected-id")).toBeDefined();
		expect(jQuery("#rating-label-"+qid).data("custom-field")).toBeDefined();
		expect(jQuery("#rating-label-"+qid).data("selected-value")).toEqual("None");
		expect(jQuery("#rating-label-"+qid).data("selected-id")).toEqual("none");
	});

	it("should clear fields on hover", function(){
		var id = span1Div.data('id');
		SurveyRating.clear(id);
		var className  = "";
		if(span1Div.attr('class').indexOf('none') != -1){
			className = "none";
		}

		expect(className).toEqual("none");
	});

	it("should fix the values" , function(){
		var id = span1Div.data('id');
		var qid = span1Div.data('question-id');
		SurveyRating.fix(id,qid);

		expect(span1Div.attr('class')).toEqual("survey-rating question-rating-3 strongly-disagree");		
	});

	it("should reset labels" , function(){
		var id = span1Div.data('id');
		var qid = span1Div.data('question-id');


		spyOn(SurveyRating, "resetLabel").and.callThrough();
		spyOn(SurveyRating, "clear");
		spyOn(SurveyRating, "fix");
		SurveyRating.resetLabel(span1Div);

		expect(SurveyRating.clear).toHaveBeenCalledWith(id);
		expect(SurveyRating.fix).toHaveBeenCalledWith(span1Div.data('selected-id'),qid);
	});

	it("should perform the input functionality", function(){
		var id = span1Div.data('id');
		var qid = span1Div.data('question-id');
		var name = span1Div.data("name");
		var labelDiv = jQuery("<label/>",{class:"rating-label-"+qid,"id":"rating-label-3","data-selected-value" : "None", "data-selected-id": "none", "data-custom-field":"cf_thank_you_for_your_valuable_feedback"}).appendTo(".pagearea");

		spyOn(SurveyRating, "input").and.callThrough();
		spyOn(SurveyRating, "updateLabel");
		spyOn(SurveyRating, "fix");
		spyOn(SurveyRating, "clear");
		SurveyRating.input(span1Div);

		expect(SurveyRating.updateLabel).toHaveBeenCalledWith(id,qid,name,true);
		expect(SurveyRating.clear).toHaveBeenCalledWith(id);
		expect(SurveyRating.fix).toHaveBeenCalledWith(id,qid);		
	});

	afterEach(function(){
		jQuery("div.pagearea").remove();
	});
});
