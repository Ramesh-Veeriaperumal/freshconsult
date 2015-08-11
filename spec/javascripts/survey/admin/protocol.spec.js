jQuery.getScript("http://localhost:3000/packages/survey_admin.jst").done(function(script){
	var head= document.getElementsByTagName('head')[0];
	var script= document.createElement('script');
	script.type= 'text/javascript';
	script.src= 'public/javascripts/survey/admin/protocol.js';
	head.appendChild(script);
	var I18nScript = document.createElement('script');
	I18nScript.type= 'text/javascript';
	I18nScript.src= 'spec/javascripts/survey/admin/I18n.js';
	head.appendChild(I18nScript);
});

describe("Survey Protocol events",function(){
	it("should define essential properties of survey protocol",function(){
		expect(SurveyProtocol).toBeDefined();
		expect(SurveyProtocol.content).toBeDefined();
		expect(SurveyProtocol.init).toBeDefined();
	});

	it("should call init function",function(){
		SurveyProtocol.init();
		expect(SurveyProtocol.getChoiceValues).toBeDefined();
		expect(SurveyProtocol.content.choiceValues).toBeDefined();
		expect(SurveyProtocol.content.action).toBeDefined();
		expect(SurveyProtocol.content.rating).toBeDefined();
		expect(SurveyProtocol.content.scale).toBeDefined();
		expect(SurveyProtocol.content.choice).toBeDefined();
		expect(SurveyProtocol.content.thanks).toBeDefined();
		expect(SurveyProtocol.content.question).toBeDefined();
		expect(SurveyProtocol.content.questions).toBeDefined();
		expect(SurveyProtocol.content.can_comment).toBeDefined();
		expect(SurveyProtocol.content.feedback_response_text).toBeDefined();
	});

	it("should get the choice values",function(){
		var choices = SurveyProtocol.content.choiceValues;
    	_.each(choices, function(element,i){
    		if(element.id  == -103){
    			expect(element.className).toEqual("strongly-disagree");
    		}
    		if(element.id == -102){
    			expect(element.className).toEqual("some-what-disagree");
    		}
    		if(element.id == -101){
    			expect(element.className).toEqual("disagree");
    		}
    		if (element.id == 100) {
    			expect(element.className).toEqual("satisfaction-neutral");
    		}
    		if (element.id == 101) {
    			expect(element.className).toEqual("agree");
    		}
    		if (element.id == 102) {
    			expect(element.className).toEqual("some-what-agree");
    		}
    		if (element.id == 103) {
    			expect(element.className).toEqual("strongly-agree");
    		}
    	});
	});

	it("should define rating elements",function(){
		expect(SurveyProtocol.content.rating.title).toBeDefined();
		expect(SurveyProtocol.content.rating.link_text).toBeDefined();
		expect(SurveyProtocol.content.rating.send_while).toBeDefined();
		expect(SurveyProtocol.content.rating.send_while.title).toBeDefined();
		expect(SurveyProtocol.content.rating.send_while.elements).toBeDefined();
		expect(SurveyProtocol.content.rating.send_while.defaultValue).toBeDefined();		
	});

	it("should define thanks elements",function(){
		expect(SurveyProtocol.content.thanks.title).toBeDefined();
		expect(SurveyProtocol.content.thanks.default_text).toBeDefined();
		expect(SurveyProtocol.content.thanks.link).toBeDefined();
		expect(SurveyProtocol.content.thanks.link.label).toBeDefined();
		expect(SurveyProtocol.content.thanks.link.action).toBeDefined();
	});

	it("should define survey question",function(){
		expect(SurveyProtocol.content.question.default_text).toBeDefined();
	});

	it("should define survey questions",function(){
		expect(SurveyProtocol.content.questions.list).toBeDefined();
		expect(SurveyProtocol.content.questions.limit).toBeDefined();
		expect(SurveyProtocol.content.questions.count).toBeDefined();
		expect(SurveyProtocol.content.questions.choiceValues).toBeDefined();
	});
});