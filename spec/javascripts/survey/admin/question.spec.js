jQuery.getScript("http://localhost:3000/packages/survey_admin.jst").done(function(script){
	var head= document.getElementsByTagName('head')[0];
	var script= document.createElement('script');
	script.type= 'text/javascript';
	script.src= 'public/javascripts/survey/admin/question.js';
	head.appendChild(script);
	var I18nScript = document.createElement('script');
	I18nScript.type= 'text/javascript';
	I18nScript.src= 'spec/javascripts/survey/admin/I18n.js';
	head.appendChild(I18nScript);
	var script= document.createElement('script');
	script.type= 'text/javascript';
	script.src= 'public/javascripts/survey/admin/protocol.js';
	head.appendChild(script);
	var script= document.createElement('script');
	script.type= 'text/javascript';
	script.src= 'public/javascripts/survey/admin/list.js';
	head.appendChild(script);
	var script= document.createElement('script');
	script.type= 'text/javascript';
	script.src= 'public/javascripts/survey/admin.js';
	head.appendChild(script);
});

describe("Survey Question Events",function(){
	beforeEach(function(){
		var pageAreaObj = jQuery("<div/>",{class:"pagearea"}).appendTo('body');
		var thanksObj = jQuery("<div/>",{id:"survey_thanks", class:"sub-container"}).appendTo('body');
		var questionObj = jQuery("<div/>",{id:"survey_questions", class:"sub-container"}).appendTo('#survey_thanks');
		var questionRatingOptions = jQuery("<div/>",{id:"question_rating_options"}).appendTo('#survey_questions');
		var questionRatingChoice = jQuery("<div/>",{id:"question_rating_choice"}).appendTo('#survey_questions');
		this.thanksDiv = thanksObj;
		this.questionsDiv = jQuery("div#survey_questions");
	});

	it("should define essential properties of questions",function(){
		expect(SurveyQuestion).toBeDefined();
		expect(SurveyQuestion.name_prefix).toBeDefined();
		expect(SurveyQuestion.id_prefix).toBeDefined();
		expect(SurveyQuestion.newFormat).toBeDefined();
		expect(SurveyQuestion.existingFormat).toBeDefined();
		expect(SurveyQuestion.survey_id).toBeDefined();
		expect(SurveyQuestion.create).toBeDefined();
		expect(SurveyQuestion.delete).toBeDefined();
		expect(SurveyQuestion.hide).toBeDefined();
		expect(SurveyQuestion.add).toBeDefined();
		expect(SurveyQuestion.setOptions).toBeDefined();
		expect(SurveyQuestion.resetOptions).toBeDefined();
	});

	it("should use existing format",function(){
		var choices =view.choice[2];
		var choiceKeys = [];
		var choiceValues = view.choiceValues;
		for(var  i=0;i<choiceValues.length;i++){
			var array = [];
			if(choiceValues[i]["id"] == choices[0]){
				array = [choiceValues[i]["text"],choiceValues[i]["id"]];
				choiceKeys.push(array);
			}
			if(choiceValues[i]["id"] == choices[1]){
				array = [choiceValues[i]["text"],choiceValues[i]["id"]];
				choiceKeys.push(array);
			}
		}

		var survey_questions = [{
						 name: "cf_thank_you_for_your_valuable_feedback",
						 type: "survey_radio",
						 field_type: "custom_survey_radio",
						 label: "Thank you for your valuable feedback.",
						 label_in_portal: "Thank you for your valuable feedback.",
						 visible_in_portal: true,
						 editable_in_portal: true,
						 required_in_portal: true,
						 id: 1,
						 choices: choiceKeys,
						 action:""
				}];
		//create an element dynamically
		var input = document.createElement("input");
		input.setAttribute("type","text");
		input.setAttribute("class", "input-survey-ques");
		input.setAttribute("data-name","cf_thank_you_for_your_valuable_feedback");
		input.setAttribute("name","survey_question[cf_thank_you_for_your_valuable_feedback]");
		input.setAttribute("value", "Thank you for your valuable feedback.");

		var questions = SurveyQuestion.existingFormat(survey_questions,input,choiceKeys);
		expect(questions).toBeDefined();
		expect(questions.label_in_portal).toBeDefined();
		expect(questions.required_in_portal).toBeDefined();
		expect(questions.required_in_portal).toBeTruthy();
		expect(questions.action).toEqual("update");
	});

	it("should create newFormat",function(){
		var createButton = this.thanksDiv.find(".pt20 label a")[0];
		var input = document.createElement("input");
		input.setAttribute("type","text");
		input.setAttribute("class", "input-survey-ques");
		input.setAttribute("data-name","Q1");
		input.setAttribute("name","survey_question[Q1]");
		input.setAttribute("value", "Are you satisfied?");

		var index = 0;
		var choiceKeys = [];
		var choices =view.choice[2];
		var choiceValues = view.choiceValues;
		for(var  i=0;i<choiceValues.length;i++){
			var array = [];
			if(choiceValues[i]["id"] == choices[0]){
				array = [choiceValues[i]["text"],choiceValues[i]["id"]];
				choiceKeys.push(array);
			}
			if(choiceValues[i]["id"] == choices[1]){
				array = [choiceValues[i]["text"],choiceValues[i]["id"]];
				choiceKeys.push(array);
			}
		}
		var question_format= SurveyQuestion.newFormat(input,index,choiceKeys);
		expect(question_format).toBeDefined();
		expect(question_format.action).toEqual("create");
	});
	
	afterEach(function(){
		jQuery("div.pagearea").remove();
		jQuery("div#survey_thanks").remove();
	});		
});