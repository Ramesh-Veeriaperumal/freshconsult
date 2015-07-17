/*
	Module deals with enabling or disabling the survey
*/
var SurveyStatus = {
	change:function(survey_id,current_status){
		if(current_status){
			SurveyStatus.enable(survey_id);
		}else{
		    SurveyStatus.disable(survey_id);
		}
	},
	enable:function(id){
		SurveyAdminUtil.showOverlay(surveysI18n.enabling_survey);
		jQuery.ajax({
			type:"POST",
			url:SurveyAdminUtil.makeURL(id,"enable"),
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
			url:SurveyAdminUtil.makeURL(id,"disable"),
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
	}
}