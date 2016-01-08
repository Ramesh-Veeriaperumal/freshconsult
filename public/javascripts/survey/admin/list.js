/*
	Module deals with survey listing related functions
*/
var SurveyList = {
	show:function(){
		SurveyAdmin.new.link.show();
		SurveyAdmin.new.remove();
		jQuery("div#survey_list").show();
		SurveyAdminUtil.hideOverlay();
	},
  enable:function(data){
    jQuery("#survey_active_"+data.active)[0].checked=true;
    jQuery("#survey_active_"+data.active).next(".toggle-button").addClass("active"); 
    if(data.inactive){
      SurveyList.disable(data);
    }
  },
  disable:function(data){
    jQuery("#survey_active_"+data.inactive)[0].checked=false;
    jQuery("#survey_active_"+data.inactive).next(".toggle-button").removeClass("active");
  },
	destroy:function(id,isEdit){
    jQuery('#SurveyConfirmContainer').html(JST["survey/admin/template/confirm_dialog"]({
      "id": id,
      "message": surveysI18n.delete_msg,
      "confirm": surveysI18n.delete,
      "confirm_type": 'delete'
    }));
    jQuery('#SurveyConfirmModal').modal('show');		
	},
  delete_survey:function(id){
    SurveyAdminUtil.showOverlay(surveysI18n.deleting_survey);
    jQuery.ajax({
      type:"DELETE",
      url:  SurveyAdminUtil.makeURL(id),
      data:{},
      success:function(data){
        SurveyAdmin.list();
        SurveyAdminUtil.hideOverlay();
      }
    });
  }
}