/*
	Module deals with agent related activities.
*/
var SurveyAgent = {
    change: function(obj){
      SurveyUtil.updateState();
	  SurveyTab.resetState();
      var agentId = jQuery(obj).val();
      var surveyId = SurveyUtil.whichSurvey().id;
      var label = jQuery(obj).find("option:selected").text();
      SurveyState.fetch(label);
    }
}