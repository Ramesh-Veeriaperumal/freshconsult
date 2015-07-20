/*
	Module deals with the data format in creating the UI.
	Captures generic elements and implements a predefined set of rules for a flawless UI dynamism.
*/
var SurveyProtocol = {
		content:{},
		init:function(){
			this.getChoiceValues = function(){
				var choices = new Array();
				/*
					choiceContents holds the values for the choices to be shown in the UI :
						actual value for that option : SurveyConstants.rating.EXTREMELY_UNHAPPY
						associated text to show : surveysI18n.strongly_disagree
						associated style class : strongly-disagree
				*/
				var choiceContents = [
					[
						SurveyConstants.rating.EXTREMELY_UNHAPPY,
						surveysI18n.strongly_disagree,
						"strongly-disagree"
					],
					[
						SurveyConstants.rating.VERY_UNHAPPY,
						surveysI18n.some_what_disagree,
						"some-what-disagree"
					],
					[
						SurveyConstants.rating.UNHAPPY,
						surveysI18n.disagree,
						"disagree"
					],
					[
						SurveyConstants.rating.NEUTRAL,
						surveysI18n.neutral,
						"satisfaction-neutral"
					],
					[
						SurveyConstants.rating.HAPPY,
						surveysI18n.agree,
						"agree"
					],
					[
						SurveyConstants.rating.VERY_HAPPY,
						surveysI18n.some_what_agree,
						"some-what-agree"
					],
					[
						SurveyConstants.rating.EXTREMELY_HAPPY,
						surveysI18n.strongly_agree,
						"strongly-agree"
					]
				];
				
				for(var i=0;i<choiceContents.length;i++){
					var obj = new Object();
					obj.id = choiceContents[i][0];
					obj.text = choiceContents[i][1];
					obj.className = choiceContents[i][2];
					choices.push(obj);
				}

				return choices;
			}
			this.content["choiceValues"] = this.getChoiceValues();
			this.content["action"]="new",
			this.content["isSurveyResult"] = false,
			this.content["isDefault"] = false,
			this.content["survey_id"] = "",
			this.content["rating"]={
				question_id: null,
				title:surveysI18n.enable_label,
				link_text:"",
				send_while:{
					title:surveysI18n.send_while_title,
					elements:[
						{
							value:SurveyConstants.notification.CLOSED_NOTIFICATION, 
							text:surveysI18n.send_while_option3
						},
						{
							value:SurveyConstants.notification.RESOLVED_NOTIFICATION, 
							text:surveysI18n.send_while_option2
						},
						{
							value:SurveyConstants.notification.ANY_EMAIL_RESPONSE, 
							text:surveysI18n.send_while_option1
						},
						{
							value:SurveyConstants.notification.SPECIFIC_EMAIL_RESPONSE, 
							text:surveysI18n.send_while_option4
						}
					],
					defaultValue: 2
				}
			},
			this.content["scale"]={
					keys:[2,3,5,7], //refers the choices in this.content["choice"]
					default:3,
					click:"SurveyProtocol.content.scale.change(this)",
					change:function(obj){
						if(obj.name=="question-choice"){
							SurveyProtocol.content.questions["choiceValues"] = SurveyProtocol.getChoiceValues();
							jQuery('#question_rating_options').html(JST["survey/admin/template/new_scale_option"]({
										"name":"question-scale",
										"choice":SurveyProtocol.content.choice.values(obj.value,"questions")
							}));
							SurveyQuestion.resetOptions();
							SurveyRating.state_object = {};
						}
						else{
							SurveyProtocol.content["choiceValues"] = SurveyProtocol.getChoiceValues();
							jQuery('#survey_rating_options').html(JST["survey/admin/template/new_scale_option"]({
										"name":"survey-scale",
										"choice":SurveyProtocol.content.choice.values(obj.value)
							}));
						}
					}
			},
			this.content["choice"]={
					2:[
							SurveyConstants.rating.EXTREMELY_UNHAPPY,
							SurveyConstants.rating.EXTREMELY_HAPPY							
					   ],
					3:[
							SurveyConstants.rating.EXTREMELY_UNHAPPY,							
							SurveyConstants.rating.NEUTRAL,				
							SurveyConstants.rating.EXTREMELY_HAPPY			
					   ],
					5:[
							SurveyConstants.rating.EXTREMELY_UNHAPPY,
							SurveyConstants.rating.VERY_UNHAPPY,														
							SurveyConstants.rating.NEUTRAL,							
							SurveyConstants.rating.VERY_HAPPY,
							SurveyConstants.rating.EXTREMELY_HAPPY
					   ],
					7:[												
							SurveyConstants.rating.EXTREMELY_UNHAPPY,		
							SurveyConstants.rating.VERY_UNHAPPY,							
							SurveyConstants.rating.UNHAPPY,
							SurveyConstants.rating.NEUTRAL,	
							SurveyConstants.rating.HAPPY,													
							SurveyConstants.rating.VERY_HAPPY,				
							SurveyConstants.rating.EXTREMELY_HAPPY			
						],
					values: function(option,type){
						var choices = [];
						if(jQuery.inArray(parseInt(option), SurveyProtocol.content.scale.keys) == -1){return;}
						var choiceValues = SurveyProtocol.content.choiceValues;
						if(type=="questions" && (SurveyProtocol.content.questions.choiceValues 
											   		&& SurveyProtocol.content.questions.choiceValues.length>0)){
								choiceValues = SurveyProtocol.content.questions.choiceValues;
						}
						for(var i=0;i<this[option].length;i++){							
							for(var c=0;c<choiceValues.length;c++){
								if(choiceValues[c].id==this[option][i]){
									choices.push(choiceValues[c]);
								}
							}
						}
						return choices;
					}
			},
			this.content["thanks"]={
				title:surveysI18n.title_text,
				default_text:surveysI18n.message_text,
				link:{
						label:surveysI18n.label_text,				
						action:"SurveyQuestion.create()"
				}
			},
			this.content["question"]={
				default_text: surveysI18n.thanks_feedback
			},
			this.content["questions"]={
				list: [ { "label": surveysI18n.default_question_text } ],
				limit: SurveyConstants.questions.LIMIT,
				count:0,
				choiceValues: SurveyProtocol.getChoiceValues()
			}
			this.content["can_comment"] = false,
			this.content["feedback_response_text"] = "",
			this.content["comments_text"] = ""
		},
		currentView:{},
		/*
			Raw json data from the server converted to UI compatible data format
		*/
		UI:function(data){
			var survey = JSON.parse(data.survey).survey;
			var protocol = jQuery.extend({},SurveyProtocol.content);
			var default_question = JSON.parse(data.default_question).survey_question;
			var choices = default_question.choices;	
			protocol.action = data.action;
			protocol.id = survey.id;
			protocol.title = survey.title_text || protocol.rating.title;
			protocol.rating.link_text = default_question.label;	
			protocol.rating.send_while.defaultValue = survey.send_while;
			protocol.rating.values = choices;
			protocol.rating.question_id = default_question.id;
			protocol.active = survey.active || false;
			protocol.isDefault = survey.default || false;
			protocol.choiceValues = protocol.choice.values(choices.length) || [];
			protocol.can_comment = survey.can_comment;
			protocol.comments_text = survey.comments_text;
			protocol.feedback_response_text = survey.feedback_response_text;
			protocol.thanks.message = survey.thanks_text;
                 this.mapChoices(protocol.choiceValues,choices);
			if(data.survey_questions){
				var survey_questions = JSON.parse(data.survey_questions);
				for(var i=0;i<survey_questions.length;i++){
					survey_questions[i] = survey_questions[i].survey_question;
				}
				if(survey_questions.length){
					protocol.questions.choices = survey_questions[0].choices;	
					protocol.questions.choiceValues = SurveyProtocol.getChoiceValues();
					protocol.questions.choiceValues = protocol.choice.values(protocol.questions.choices.length,"questions") || [];
                            this.mapChoices(protocol.questions.choiceValues,survey_questions[0].choices);
				}
				
				_.each(survey_questions,function(question){					
					choiceArray = _.map(question.choices,function(choice){return choice.id;});
					question.choiceMap = {};
					_.each(choiceArray,function(choiceId,index){
						question.choiceMap[(index+1)] = choiceId;
					});
				});
				
				protocol.questions.exists = ( survey_questions.length > 0 );
	
				if(protocol.questions.exists){	
					protocol.questions.list = survey_questions;
				}				

			}
			protocol.isSurveyResult = data.survey_result_exists;
			return protocol;
		},
		mapChoices:function(format,choices){
			for(var i=0;i<format.length;i++){
      			for(var c=0;c<choices.length;c++){
      		  	   if(format[i].id==choices[c].face_value){	
      				format[i].value = choices[c]["value"];
      				format[i]["editVal"] = choices[c]["value"];
                            format[i]["position"] = choices["position"];
      			   }
      			}
			}
		}
}