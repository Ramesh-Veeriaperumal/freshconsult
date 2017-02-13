/*
	Module handles the functionalities related to detail UI
*/
var SurveyDetail = {
	 preview:function(id){
			SurveyAdminUtil.showOverlay(surveysI18n.previewBegin);
			jQuery.ajax({
				type:'POST',
				url:SurveyAdmin.path+id+"/test_survey",
				success:function(data){
					SurveyAdminUtil.hideOverlay();
					flash = jQuery("#noticeajax").html(surveysI18n.previewEnd).show();
					closeableFlash(flash);
				},
				error:function(data){
					SurveyAdminUtil.hideOverlay();
				}
			});
	 },
	 createChoices:function(choices){
	 	var formattedChoices = [];
	 	for(var i=0;i<choices.length;i++){
			formattedChoices[i]={};
			if(choices[i].value.trim().length == 0){
				formattedChoices[i].value = choices[i].placeholder;
			}else{
				formattedChoices[i].value = choices[i].value != '' ? choices[i].value : choices[i].attr('placeholder');
			}
			formattedChoices[i].face_value = jQuery(choices[i]).data('face-value');
			formattedChoices[i].position = jQuery(choices[i]).data('position') || (i+1);
			formattedChoices[i]._destroy = 0;
		}
		return formattedChoices;
	 },

	 parseFormData:function(obj){
		var survey_fields = jQuery("form[name=survey_fields]").serializeArray();
		var survey = {};
		for(var i=0;i<survey_fields.length;i++){
			var element = survey_fields[i];
			if(element.name=="title_text" 
					|| element.name=="thanks_text"
					|| element.name=="comments_text"
					|| element.name=="feedback_response_text"
					|| element.name=="send_while"){
				survey[element.name] = element.value  || jQuery("input[name="+element.name+"]").attr('placeholder');
			}
		}
		survey["good_to_bad"] = SurveyAdmin.surveyChoiceGoodToBad;
		survey["can_comment"] = jQuery("input[name=can_comment]").length > 0 ? jQuery("input[name=can_comment]")[0].checked : true;
		survey.active = jQuery("input[name=active]").length > 0 ? jQuery("input[name=active]")[0].checked : false;

		var scale = jQuery("textarea[name=survey-scale]");
		var default_question = {
			choices: this.createChoices(scale),
			id: jQuery("input[name=question_id]"),
			link_text: jQuery("input[name=link_text]").val()  || surveysI18n.link_text_input_label,
			choicemap: jQuery("input[name=link_text]").data('choicemap')
		};
	
		var survey_questions = [];
		var default_question_format = SurveyQuestion.defaultFormat(default_question);
		survey_questions.push(default_question_format);
		var jsonData = jQuery(jQuery(obj).find("input[name=jsonData]")[0]).val();
		if(jsonData != ""){ jsonData = JSON.parse(jsonData); }
		var surveyQuestionForm = jQuery(obj);
		var survey_choices = jQuery("textarea[name^=question-scale]");
		var choices = this.createChoices(survey_choices);
		var survey_question_fields = jQuery("input[name^=survey_question]");
		for(i=0;i<survey_question_fields.length;i++){
				var name = jQuery(survey_question_fields[i])[0].name;
				var question_format = null;
				if(name.indexOf("cf_")!=-1){
					question_format = SurveyQuestion.existingFormat(jsonData,jQuery(survey_question_fields[i])[0],choices);
				}
				else{
					question_format = SurveyQuestion.newFormat(jQuery(survey_question_fields[i])[0],i,choices);
				}
				survey_questions.push(question_format);
		}
		if(SurveyQuestion.removeFlag){
			for(i=0;i<jsonData.length;i++){
				if(jsonData[i].id){
					SurveyQuestion.items.push(jsonData[i].id);
				} 
			}
		}
	    	for(i=0;i<SurveyQuestion.items.length;i++){
	    		var deleted_format = SurveyQuestion.deletedFormat(SurveyQuestion.items[i]);
			survey_questions.push(deleted_format);
	   	 }
	    survey_questions = SurveyQuestion.formatChoices(survey_questions);
		jQuery(obj).find("input[name=survey]").val(SurveyJSON.stringify(survey));
		jQuery(obj).find("input[name=jsonData]").val(SurveyJSON.stringify(survey_questions));
    		return survey_question_fields;
	},
	rating:{
		create:function(view){
			view.rating.surveyLimit = SurveyAdmin.fullSurvey;
			jQuery('#survey_rating').html(JST["survey/admin/template/new_rating"](view.rating));
			jQuery('#survey_link_scenarios').html(JST["survey/admin/template/new_send_while"](view.rating));
			var defaultScale = (view.rating.values && view.rating.values.length>=2) ? view.rating.values.length : view.scale.default;
			jQuery('#survey_rating_options')
					.html(JST["survey/admin/template/new_scale_option"]({
									"name":"survey-scale",
									"choice":view.choice.values(defaultScale),
									"surveyLimit": SurveyAdmin.fullSurvey
			}));	
			jQuery('#survey_rating_choice')
					.html(JST["survey/admin/template/new_rating_choice"]({
							name:"choice",
							"scale":view.scale,
							"defaultScale":defaultScale
			}));	
		}
	},
	thanks:{
		create:function(view){
			view.surveyLimit = SurveyAdmin.fullSurvey;
			view.hasLayoutCustomization = SurveyAdmin.hasLayoutCustomization;
			jQuery('#survey_thanks').html(JST["survey/admin/template/new_thanks"](view));
		}
	}
}