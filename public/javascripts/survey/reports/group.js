/*
	Module deals with group related activities.
*/
var SurveyGroup = {
    change: function(obj){
      SurveyUtil.updateState();
	  SurveyTab.resetState();
      var groupId = jQuery(obj).val();
      var label = jQuery(obj).find("option:selected").text();
      SurveyState.fetch(label);
    }
}