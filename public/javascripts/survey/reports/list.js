/*
	Module deals with events associated with surveys list.
*/
var SurveyList = {
      change: function(obj){
      		SurveyUtil.updateState();
      		SurveyTab.resetState();
            var surveyId = jQuery(obj).val();
            var label = jQuery(obj).find("option:selected").text();
            SurveyState.fetch(label);

      }
}