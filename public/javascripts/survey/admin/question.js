/*
	Module deals with the life-cycle of a question
*/
var SurveyQuestion = {
	name_prefix: "Q",
	items:[],
	removeFlag: false,
	id_prefix: "survey_question",
	newFormat:function(field,index,choices){
		var question_format = {
				 name: "Q"+(index+1),
				 type: "survey_radio",
				 field_type: "custom_survey_radio",
				 id: null,
				 action:"create",
				 default: false,
				 custom_field_choices_attributes: JSON.parse(SurveyJSON.stringify(choices)),
				 label: field.value
		};
		return question_format;
	},
	existingFormat:function(survey_questions,field,choices){
		for(var i=0;i<survey_questions.length;i++){
			if(field.id == survey_questions[i].id){
				survey_questions[i].label = field.value;
				survey_questions[i].action = "update";
				survey_questions[i].default = false;
				survey_questions[i].custom_field_choices_attributes = JSON.parse(SurveyJSON.stringify(choices));
				survey_questions[i].choiceMap = jQuery(field).data('choicemap');
				return survey_questions[i];
			}
		}
	},
	deletedFormat:function(id){
		var deleted_format = {
			id:parseInt(id),
			action: "delete"
		};
		return deleted_format;
	},
	defaultFormat: function(default_question){
		var default_format = {
				 type: "survey_radio",
				 field_type: "custom_survey_radio",
				 label: default_question.link_text,
				 id: jQuery(default_question.id).length > 0 ? parseInt(jQuery(default_question.id).val()) : null,
				 custom_field_choices_attributes: default_question.choices,
				 action: jQuery(default_question.id).length > 0 ? "update" : "create",
				 default: true,
				 choiceMap: default_question.choicemap
		};
		return default_format;
	},
	formatChoices:function(questions_format){
		var position = 1;
		_.each(questions_format, function(question){
			question.position = position++;
			if(question.action == "update"){
				var choiceMap = jQuery.extend({},question.choiceMap);
				_.each(question.custom_field_choices_attributes, function(choice){
					if(choiceMap[choice.face_value]){
						choice.id = choiceMap[choice.face_value];
						delete choiceMap[choice.face_value];
					}
				});
				_.each(choiceMap, function(deleted_id){
					question.custom_field_choices_attributes.push({id: deleted_id, _destroy: true});
				});
			}
			_.each(["choices","name", "deleted"], function(attr){
				delete question[attr];
			});
		});
		return questions_format;
	},
	survey_id: null,
	hideOptions:function(view){
		jQuery("div#survey_rating_choice").hide();
		jQuery("a#question-cancel").hide();
    jQuery('div#survey_question_set').find('a.delete-question').hide();
		jQuery("div#question_rating_choice").hide();
    jQuery('#survey_point_scale').text(surveysI18n.scale_text + " " +SurveyProtocol.content.choices.length+ " " +surveysI18n.scale).removeClass("spanhack");
    jQuery('#question_point_scale').text(surveysI18n.scale_text + " " +SurveyProtocol.content.question_choices.length+ " " +surveysI18n.points_scale).removeClass("spanhack");
		jQuery(".add-srvy-ques").hide();
    jQuery('div#comments').find("input[name='can_comment']").attr('disabled',true);
	},
	showOptions:function(){
    jQuery('div#survey_question_set').find('a.delete-question').show();
		jQuery('div#survey_question_set').find('li.delete-question').show();
		jQuery("div#survey_rating_choice").show();
    jQuery("div#question_rating_choice").show();  
    SurveyProtocol.content.questions.count >= SurveyProtocol.content.questions.limit ? 
    jQuery('.add-srvy-ques').hide() : jQuery(".add-srvy-ques").show();
    jQuery('div#comments').find("input[name='can_comment']").attr('disabled',false);
	},
  //To refelect changes on the icon text as and when the question scale value changes
  updateOptionValues: function(){
      var defaultScale = jQuery("input[name=question-choice]:checked").val();
      var choices = SurveyProtocol.content.choice.values(defaultScale,"questions");
      jQuery("div#question_rating_options").find('li input').each(function(index,value){
        if(jQuery(this).attr('value').length > 0 && jQuery(this).attr('value')!= ""){
          choices[index]["value"] = escapeHtml(jQuery(this).attr('value'));
        }else{
          choices[index]["value"] = jQuery(this).attr('placeholder');           
        }
      });
      var count = jQuery('div#survey_question_set .question').length;
      for(var i=1;i<=count;i++){
        SurveyQuestion.setOptions(i,choices); 
      }
  },
	create:function(view){
		if(view){
			SurveyQuestion.survey_id = view.id;
		}else{
			SurveyQuestion.survey_id = null;
		}
		SurveyQuestion.removeFlag = false;
		view = view || SurveyProtocol.currentView;
		if(view.questions.list.length==0 || jQuery("div#survey_questions").css('display')!="none"){return;}
		jQuery("div#survey_questions").html("");
		jQuery("div#survey_questions").css('display',"block");
		var data = view.thanks;
		var defaultScale = (view.questions.choices && view.questions.choices.length>=2) ? view.questions.choices.length : view.scale.default;
 		jQuery('div#survey_questions').append(JST["survey/admin/template/new_questions_layout"](view.questions));
		jQuery('#addQuestion').hide();
		jQuery('#additional-thanks').show();
		jQuery('#question_rating_options').html(
				JST["survey/admin/template/new_scale_option"]({
					"name":"question-scale",
					"choice":view.choice.values(defaultScale,"questions"),
					"surveyLimit": SurveyAdmin.fullSurvey
				})
		);
		jQuery('#question_rating_choice').html(
				JST["survey/admin/template/new_rating_choice"]({
					name:"question-choice",
					scale:view.scale,
					defaultScale:defaultScale
				})
		);
		jQuery('.survey-questions-wrap').sortable({
			handle: '.rearrange-icon',
			cursor: 'move',
			containment: '.survey-questions-wrap',
			items: '.question'
		});
		view.questions.count = 0;
		for(var i=0;i<view.questions.list.length;i++){
			this.add(view.questions.list[i],view.isSurveyResult);
		}
		if(view.action=="edit"){
			jQuery("input[name=jsonData]").val(SurveyJSON.stringify(view.questions.list));
		}
		jQuery("div#question_rating_options input").on("input",function(){
			 SurveyQuestion.updateOptionValues();
		});
	},
	delete:function(id,questionId){

		jQuery('div#survey_question_set .question').each(function(){
			if(jQuery(this).attr('id') == id){ 
				jQuery(this).remove();
				SurveyProtocol.content.questions.count = jQuery('div#survey_question_set .question').length;
			}
		});
		if(SurveyQuestion.survey_id && questionId){
			SurveyQuestion.items.push(questionId);
		}
		if(SurveyProtocol.content.questions.count < SurveyProtocol.content.questions.limit){
			jQuery('.add-srvy-ques').show();
		}
	},
	remove_dialog:function(){
		jQuery('#SurveyConfirmContainer').html(JST["survey/admin/template/confirm_dialog"]({
			"id": 0,
			"message": surveysI18n.remove_msg,
			"confirm": surveysI18n.hide,
			"confirm_type": 'remove'
		}));
		jQuery('#SurveyConfirmModal').modal('show');
	},
	hide:function(){
		jQuery('div#survey_questions').hide();
		jQuery("div#survey_questions").html("");
		if(!jQuery("input[name=can_comment").is(':checked'))
		 {
		 	jQuery("#additional-thanks").hide();
		 }
    	jQuery('#addQuestion').show();
	},
	add:function(question,isSurveyResult){
		var surveyQuestionId = 0;
		var constructQuestionJson = function(){
			//construct a new question format on adding a question while editing and creating a survey
			if(!original_question){
				question = {};
				question.label = surveysI18n.default_question_text;
				question.name = SurveyQuestion.name_prefix + SurveyProtocol.content.questions.count;
				surveyQuestionId = SurveyQuestion.id_prefix+"_"+SurveyProtocol.content.questions.count;
			}else{
				//Edit questions during update
				surveyQuestionId = SurveyQuestion.id_prefix+"_"+SurveyProtocol.content.questions.count;
				question.name = question.name || SurveyQuestion.name_prefix + SurveyProtocol.content.questions.count;	
			}
		};

		var original_question = question;
		question = question || SurveyProtocol.content.questions.list[0];				
		SurveyProtocol.content.questions.count++;
		constructQuestionJson();
		var view = SurveyProtocol.content;
		var defaultScale = jQuery("input[name=question-choice]:checked").val();
		var choices = SurveyProtocol.content.choice.values(defaultScale,"questions");
		jQuery("div#survey_question_set").append(
				JST["survey/admin/template/new_question"]({
						"surveyQuestionId":surveyQuestionId,
						"content":SurveyProtocol.content,
						"count":view.questions.count,
						"choices":choices,
						"question":question
				})
		);
		if(SurveyProtocol.content.questions.count>=SurveyProtocol.content.questions.limit) {
			jQuery('.add-srvy-ques').hide();
			return;
		}
		SurveyQuestion.setOptions(view.questions.count,choices);
    this.updateOptionValues();
	},
	//ignore edit if survey results are already present
	defaultOptions: function(surveyProtocol){
    if(surveyProtocol.isSurveyResult || surveyProtocol.isDefault){	
      SurveyQuestion.hideOptions(surveyProtocol);
      jQuery('#addQuestion').hide();
    }else{
      SurveyQuestion.showOptions();
    }
	},
	setOptions:function(count,choices){
		jQuery("li#question-rating-option-"+count).html(
				JST["survey/admin/template/new_question_option"]({
						"count":count,
						"choices":choices
				})
		);
	},
	additionalComment: function(){
		jQuery('#feedback-thanks').toggle();
		if(jQuery('#addQuestion').is(':visible'))
		{
			jQuery("#additional-thanks").toggle();
		}
	},
	resetOptions:function(){
		var defaultScale = jQuery("input[name=question-choice]:checked").val();
		var choices = SurveyProtocol.content.choice.values(defaultScale,"questions");
		var ratingOptionArray = jQuery(".question-rating-option");
		for(var r=0; r<ratingOptionArray.length;r++){
			var optionObj = jQuery(ratingOptionArray[r]);
			var label = jQuery(optionObj.find("label"));
			var selectedId = label.data('selected-id');					
			optionObj.html(
				JST["survey/admin/template/new_question_option"]({
						"count":r,
						"choices":choices
				})
			);
		}
	}
}