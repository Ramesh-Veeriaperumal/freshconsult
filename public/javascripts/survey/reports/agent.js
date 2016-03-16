/*
	Module deals with agent related activities.
*/
var SurveyAgent = {
    change: function(obj){
      SurveyUtil.updateState();
      var agentId = jQuery(obj).val();
      var surveyId = SurveyUtil.whichSurvey().id;
      SurveyState.filterChanged = true;
      SurveyState.fetch();
    }
}