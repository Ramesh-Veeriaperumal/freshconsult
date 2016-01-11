/*
    Core module for surveys admin activities.
*/
var SurveyAdmin = {	
		fullSurvey: true,
		path: "/admin/custom_surveys/",
		setFullSurvey: function(defaultSurveyFlag){
			SurveyAdmin.fullSurvey = defaultSurveyFlag;
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