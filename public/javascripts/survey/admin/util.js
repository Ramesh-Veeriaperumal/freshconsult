/*
	Module to deal with the miscellaneous stuff or generic elements which can be 
	used across different modules.
*/
var SurveyAdminUtil = {
		showOverlay: function(msg){
			jQuery('.survey-overlay').show();
			jQuery('.survey-overlay-text').text(msg);
		},
		hideOverlay: function(){
			jQuery('.survey-overlay').hide();
		},
		makeURL: function(id,action){
			return action ? SurveyAdmin.path+action+"/"+id : SurveyAdmin.path+id;
		},
	action:{
		split:function(action){
			if(action.indexOf("/") != -1){
				return action.split("/")[0];
			}
			return action;
		}
	}
}