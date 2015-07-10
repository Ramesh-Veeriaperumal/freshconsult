/*
   	Feedback related functions consolidated here. 
	This module has been used in "portal" as well as "rating page via survey handle".
*/
var Feedback = {
	submit:function(event){
		Feedback.showOverlay(surveyFeedbackI18n.surveyFeedback);
		var action = jQuery("#survey_form").attr("action");
		var data = Feedback.fetch();
		if(!isPreview || hasQuestandComments){
			jQuery.ajax({
				url: action,
				type: "POST",
				data: data
			}).done(function(data){
				Feedback.hide(data);
				if(document.referrer.length>0){
					hasQuestandComments = true;
					Feedback.refreshTab();
				}
			});
		}else{
			Feedback.hide();
		}
		event.stopPropagation();
		event.preventDefault();
		return false;
	},
	fetch:function(){
		var labels = jQuery('.rating-label');
		var params = {};
		var custom_fields = {};
		for(var l=0;l<labels.length;l++){	
			var obj = jQuery(labels[l]);
			if(obj.data('selected-id')!="none"){
				custom_fields[obj.data('custom-field')] = obj.data('selected-id');
			}
		}
		if(isCommentable){
			params["feedback"] = jQuery("input[name=feedback]").val();
		}
		params["custom_field"] = custom_fields;
		return params;
	},
	showOverlay: function(msg){
		jQuery('.survey-overlay').show();
		jQuery('.loading').show();
		jQuery('.loading').text(msg);
		jQuery('#survey_question').hide();
	},
	hideOverlay: function(){
		jQuery('.survey-overlay').hide();
		jQuery('.loading').hide();
	},
	hide: function(data){
		jQuery(".question").remove();
		Feedback.hideOverlay();
		var msgObj = jQuery(".highlighter").find("h2");
		var msg = data.thanks_message && data.thanks_message.length > 0 ? data.thanks_message : surveyFeedbackI18n.thanksFeedback;
		msgObj.text(msg);
	},
	refreshTab: function(){		
		if(hasQuestandComments){
			jQuery('.loading').show();
			jQuery('.loading').text(surveyFeedbackI18n.portalMsg);
			setTimeout(function(){ 
				window.close();
				window.opener.location.reload();
			}, 3000);
		}
	}
}