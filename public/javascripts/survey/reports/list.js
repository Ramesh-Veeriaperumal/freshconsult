/*
	Module deals with events associated with surveys list.
*/
var SurveyList = {
      change: function(obj){
      		SurveyUtil.updateState();
      		SurveyTab.resetState();
            var surveyId = jQuery(obj).val();
      		SurveyState.filterChanged = true;
            SurveyState.fetch();

      }
}