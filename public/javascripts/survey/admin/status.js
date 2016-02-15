/*
	Module deals with enabling or disabling the survey
*/
var SurveyStatus = {
	change:function(survey_id,current_status){
		if(current_status){
			var isActive= this.findActive();
			if(isActive!=0){
				jQuery('#survey_active_'+survey_id).prop('checked', false).siblings('.toggle-button').removeClass('active');
				jQuery('#TogglesurveyActivate').prop('checked', false).siblings('.toggle-button').removeClass('active');
				jQuery('#SurveyConfirmContainer').html(JST["survey/admin/template/confirm_dialog"]({
					"id": survey_id,
					"message": surveysI18n.activate_msg,
					"confirm": surveysI18n.activate,
					"confirm_type": 'activate'
				}));
				jQuery("#active_survey_name").html(isActive);
				jQuery('#SurveyConfirmModal').modal('show');
			}
			else if(survey_id!=0){
				SurveyStatus.enable(survey_id);
			}
		}else{
			if(survey_id!=0){
		    	SurveyStatus.disable(survey_id);
		    }
		}
	},
	enable:function(id){
		SurveyAdminUtil.showOverlay(surveysI18n.enabling_survey);
		jQuery.ajax({
			type:"POST",
			url:SurveyAdminUtil.makeURL(id,"activate"),
			data:{},
			success:function(data){
        if(jQuery('#survey_list').length > 0){
				  	SurveyList.enable(data);
            SurveyAdmin.list();
		    }
          SurveyStatus.update(data.active,true);
          SurveyAdminUtil.hideOverlay();
          
				}
		});
	},
	disable:function(id){
		SurveyAdminUtil.showOverlay(surveysI18n.disabling_survey);
		jQuery.ajax({
			type:"POST",
			url:SurveyAdminUtil.makeURL(id,"deactivate"),
			data:{},
			success:function(data){
				if(jQuery('#survey_list').length > 0){
          SurveyList.disable(data);
          SurveyAdmin.list();
        }
        SurveyStatus.update(data.inactive,false);
        SurveyAdminUtil.hideOverlay();
			}
		});
	},
	confirmHandler:function(survey_id, type){
		jQuery('#SurveyConfirmModal').modal('hide');
		switch(type){
			case 'activate':	
				jQuery('#TogglesurveyActivate').prop('checked', true).siblings('.toggle-button').addClass('active');
				jQuery('#survey_active_'+survey_id).prop('checked', true).siblings('.toggle-button').addClass('active');
				if(survey_id !== 0){
					SurveyStatus.enable(survey_id);
				}
				break;
			case 'delete':
				SurveyList.delete_survey(survey_id);
				break;
			case 'remove':
				SurveyQuestion.hide();
				break;
			default:
				break;

		}
	},
	update:function(id,status){
  		_.each(survey_list, function(item){
  			if(item.survey.id==id){						
  				item.survey.active=status;
  			}
  		});
	    jQuery('.survey-delete').removeAttr('disabled');
	    if(status){
	      jQuery('a#survey_'+id).attr('disabled',true);
	      jQuery('a#survey_'+id).attr('onclick',null);
	    }else{
	      jQuery('a#survey_'+id).attr('onclick','SurveyList.destroy('+id+',false)');
	    }
	},
	findActive:function(){
		for(i=0; i<survey_list.length;i++){
			if(survey_list[i].survey.active==1){
				return survey_list[i].survey.title_text;
			}
		}
		return 0;
	}
}