/*
	Module deals with validating elements before making a request.
*/
var SurveyValidate = {
	initialize: function(){
		jQuery("form[name=survey]").submit(function(event){
			var survey_questions = SurveyDetail.parseFormData(this);
			if(SurveyValidate.isUniqueName() && 
        SurveyValidate.questions.isBlank(survey_questions) && SurveyValidate.questions.isUnique(survey_questions)){
				jQuery(this).ajaxSubmit(function(data){
					survey_list = JSON.parse(data.surveys);
					if(data.errors){
						jQuery("#error").html(data.errors).show();
						closeableFlash("#error");
						jQuery("body").scrollTop(0);
						return;
					}
					SurveyAdmin.list();
				});
			}
			event.stopPropagation();
			event.preventDefault();
			return false;
		});
	},
  questions:{
    isUnique: function(questions){
      if(questions.length>0){
          for(i=0;i<questions.length;i++){
            if(jQuery(questions[i])[0].value == jQuery('input[name="link_text"]').val()){
                var value = jQuery(questions[i])[0].value;
                jQuery(questions[i]).focus();
                jQuery(questions[i]).addClass('error');
                jQuery('.input-survy-ques.error').parents('div.question').find('label#question-text-error').text(surveysI18n.question_error_text);
                jQuery('.input-survy-ques.error').parents('div.question').find('label#question-text-error').show();
                return false;
            }
            for(j=i+1;j<questions.length;j++){
              if(jQuery(questions[i])[0].value == jQuery(questions[j])[0].value){
                var value = jQuery(questions[j])[0].value;
                jQuery(questions[j]).focus();
                jQuery(questions[j]).addClass('error');
                jQuery('.input-survy-ques.error').parents('div.question').find('label#question-text-error').text(surveysI18n.question_error_text);
                jQuery('.input-survy-ques.error').parents('div.question').find('label#question-text-error').show();
                return false;
              }else{
                jQuery('.input-survy-ques.error').parents('div.question').find('label#question-text-error').hide();
                jQuery(questions[j]).removeClass('error');
              }
            }
          }
        }
      return true;
    },
    isBlank: function(questions){
      for(i=0;i<questions.length;i++){
        if(jQuery.trim(jQuery(questions[i])[0].value).length == 0){
          jQuery(questions[i]).focus();
          jQuery(questions[i]).addClass('error');
          jQuery('.input-survy-ques.error').parents('div.question').find('label#question-text-error').text(surveysI18n.empty_text);
          jQuery('.input-survy-ques.error').parents('div.question').find('label#question-text-error').show();
          return false;
        }else{
          jQuery('.input-survy-ques.error').parents('div.question').find('label#question-text-error').hide();
          jQuery(questions[i]).removeClass('error');
        }
      }
      return true;
    }
  },
	isUniqueName:function(){
     var removeErrorClass = function(){
        jQuery('input[name=title_text]').removeClass('error');
        jQuery('#title_text-error').hide();
     }
     jQuery('input[name=title_text]').on('blur',function(){
        removeErrorClass();
     });
	   var title_text = jQuery('input[name=title_text]').val() || jQuery('input[name=title_text]').attr('placeholder');
     var id = jQuery("form[name=survey]").attr('surveyId');
	    for(var i=0;i<survey_list.length;i++){
	      if(id != ''){
	        if(survey_list[i].survey.id == id && survey_list[i].survey.title_text == title_text ){
	            return true;
	        }
	      }
	      if(survey_list[i].survey.title_text == title_text){
          jQuery('input[name=title_text]').addClass('error');
	        jQuery('#title_text-error').show();
          jQuery('input[name=title_text]').focus();
	        return false;
	      }else{
          removeErrorClass();
	      }
			}
        return true;
	},
  removeError:function(questObj){
    jQuery(questObj).removeClass('error');
    jQuery(questObj).parents('div.question').find('label#question-text-error').hide();
  }
}
