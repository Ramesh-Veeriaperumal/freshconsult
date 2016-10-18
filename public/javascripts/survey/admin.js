/*
    Core module for surveys admin activities.
*/
var SurveyAdmin = {	
		fullSurvey: true,
		hasLayoutCustomization: false,
		surveyChoiceGoodToBad: true,
		path: "/admin/custom_surveys/",
		flipChoiceOrder:function(obj){
			if(jQuery(obj).data('state')!=SurveyAdmin.surveyChoiceGoodToBad){
				SurveyAdmin.surveyChoiceGoodToBad = !SurveyAdmin.surveyChoiceGoodToBad;
				var choice_default = jQuery('#survey_rating_options .flexcontainer textarea');
				jQuery('#survey_rating_options .flexcontainer').prepend(choice_default.get().reverse());
				var choice_questions = jQuery('#question_rating_options .flexcontainer textarea');
				jQuery('#question_rating_options .flexcontainer').prepend(choice_questions.get().reverse());
				jQuery('.question-rating-option').each(function(){
					var choice_rating = jQuery(this).find('.survey-rating');
					jQuery(this).append(choice_rating.get().reverse());
				});
				jQuery('.rating_order_select .dropdown-menu li').toggleClass('active');
				jQuery('#order_dropdown h5').toggleClass('good_to_bad bad_to_good').html(jQuery(obj).text()+"<b class='caret'></b>");
			}
			
		},
		render:function(view){
			SurveyDetail.rating.create(view);
			SurveyDetail.thanks.create(view);
			if(view.action=="edit" && view.questions.exists && SurveyAdmin.fullSurvey){
				SurveyQuestion.create(view);
			}
			SurveyValidate.initialize();
			SurveyProtocol.currentView = view;
		},
		list:function(){
			pjaxify(SurveyAdmin.path);
		},
		new:{
			link:{
				show:function(){
					jQuery('#newSurvey').show();
				},
				hide:function(){
					jQuery('#newSurvey').hide();
				}
			},
			show: function(){
			 	SurveyAdmin.new.link.hide();			
				jQuery("#survey_list").hide();
				SurveyProtocol.init();
				SurveyAdmin.render(SurveyProtocol.content);
				jQuery('#survey_new_layout').show();
			},
			remove: function(){
				jQuery("div#survey_new_layout").remove();
			}
		},
		edit:function(surveyDetails){
			SurveyProtocol.init();
			var surveyProtocol = SurveyProtocol.UI(surveyDetails);
			SurveyAdmin.render(surveyProtocol);
			jQuery('a#previewFeedback').show();
			(surveyProtocol.active || surveyProtocol.isDefault) ? jQuery('input#deleteSurvey').hide() 
                           				 :  jQuery('input#deleteSurvey').show();
            		jQuery('#survey_new_layout').show();
          		SurveyQuestion.defaultOptions(surveyProtocol);
		}
}