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
					SurveyAdminUtil.showOverlay(surveysI18n.previewEnd);
					setTimeout( function(){
						SurveyAdminUtil.hideOverlay();
					},1000);
				},
				error:function(data){
					SurveyAdminUtil.hideOverlay();
				}
			});
	 },
	 parseFormData:function(obj){
		var survey_fields = jQuery("form[name=survey_fields]").serializeArray();
		var survey = {};
		survey["choices"] = [];
		for(var i=0;i<survey_fields.length;i++){
			var element = survey_fields[i];
			if((element.name!="" && element.name!="can_comment" 
									&& element.name!="survey-scale" 
									&& element.name.indexOf("scale")==-1
									&& element.name.indexOf("question")==-1)
				|| element.name.indexOf("question_id")!=-1){

					survey[element.name] = element.value;
			}
		}
		
		survey["can_comment"] = jQuery("input[name=can_comment]")[0].checked;
		var scale = jQuery("input[name=survey-scale]");
		for(var i=0;i<scale.length;i++){
			if(scale[i].value.trim().length == 0){
				survey["choices"].push([scale[i].placeholder,jQuery(scale[i]).data('face-value')]);
			}
			else{
				survey["choices"].push([scale[i].value,jQuery(scale[i]).data('face-value')]);
			}
		}
		
		survey.active = jQuery("input[name=active]").length > 0 ? jQuery("input[name=active]")[0].checked : false;
		var survey_questions = [];
		var jsonData = jQuery(jQuery(obj).find("input[name=jsonData]")[0]).val();
		if(jsonData != ""){ jsonData = JSON.parse(jsonData); }
		// var surveyQuestionForm = jQuery("form[name=survey_question_fields]")	;
		var surveyQuestionForm = jQuery(obj);
		var survey_choices = jQuery("input[name^=question-scale]");
		var survey_question_fields = jQuery("input[name^=survey_question]");
		var choices = [];
		for(var i=0;i<survey_choices.length;i++){
			if(survey_choices[i].value.trim().length == 0){
				choices[i] = [survey_choices[i].placeholder,jQuery(survey_choices[i]).data('face-value')];
			}else{
				choices[i] = [survey_choices[i].value,jQuery(survey_choices[i]).data('face-value')];
			}
			var position = (i+1);
			if(jQuery(survey_choices[i]).data('position')){ position = jQuery(survey_choices[i]).data('position'); }
			choices[i].push(position);
		}

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

		jQuery(obj).find("input[name=survey]").val(JSON.stringify(survey));
		jQuery(obj).find("input[name=jsonData]").val(JSON.parse(JSON.stringify(survey_questions)));
		jQuery(obj).find("input[name=deleted]").val(SurveyQuestion.items);
    		return survey_question_fields;
	},
	rating:{
		create:function(view){
			jQuery('#survey_rating').html(JST["survey/admin/template/new_rating"](view.rating));
			var defaultScale = (view.rating.values && view.rating.values.length>=2) ? view.rating.values.length : view.scale.default;
			jQuery('#survey_rating_options')
					.html(JST["survey/admin/template/new_scale_option"]({
									"name":"survey-scale",
									"choice":view.choice.values(defaultScale)	
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
			jQuery('#survey_thanks').html(JST["survey/admin/template/new_thanks"](view));
		}
	}
}