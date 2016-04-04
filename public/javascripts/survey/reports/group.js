/*
	Module deals with group related activities.
*/
var SurveyGroup = {
    change: function(obj){
      SurveyUtil.updateState();
      var groupId = jQuery(obj).val();
      SurveyState.filterChanged = true;
      SurveyState.fetch();
    }
}