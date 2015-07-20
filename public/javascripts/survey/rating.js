/*
   	Rating related functions consolidated here. 
	This module has been used in admin & rating page.
*/
var SurveyRating = {
	state_object: {},
	input:function(obj,isPreview){
		var ratingObj = jQuery(obj);
		SurveyRating.state_object = ratingObj;
		this.updateLabel(
			ratingObj.data('id'),
			ratingObj.data('question-id'),
			ratingObj.data("name"),
			!isPreview
		);
		this.clear(ratingObj.data("question-id"));
		this.fix(
			ratingObj.data("id"), 
			ratingObj.data("question-id")
		);
	},
	hover:function(obj){
		var ratingObj = jQuery(obj);					
		this.updateLabel(
			ratingObj.data('id'),
			ratingObj.data('question-id'),
			ratingObj.data("name")
		);
		this.clear(ratingObj.data("question-id"));
		this.fix(
			ratingObj.data("id"), 
			ratingObj.data("question-id")
		);
	},
	resetLabel:function(obj){
		var id = jQuery(obj).data('question-id');
		var labelObj = jQuery("#rating-label-"+id);
		labelObj.text(
			labelObj.data("selected-value")
		);
		this.clear(id);
		this.fix(
			labelObj.data('selected-id'),
			id
		);
	},
	updateLabel:function(id,qid,name,isSelected){
		jQuery("#rating-label-"+qid).text(name);
		if(isSelected){
			jQuery("#rating-label-"+qid).data(
				"selected-value",
				name
			);
			jQuery("#rating-label-"+qid).data(
				"selected-id",
				id
			);
		}
	},
	fix:function(id,qid){
		if(id=="none"){return;}
		var ratingArray = jQuery(".question-rating-"+qid);
		for(var i=0;i<ratingArray.length;i++){
			var ratingObj = jQuery(ratingArray[i]);
			if(id == ratingObj.data("id")){
				var ratingClass = ratingObj.data("class");
				ratingObj.addClass(ratingClass);
				ratingObj.removeClass("none");
			 	break; 
			}
		}
	},
	clear:function(id){
		var ratingArray = jQuery(".question-rating-"+id);
		for(var i=0;i<ratingArray.length;i++){
			var ratingObj = jQuery(ratingArray[i]);
			ratingObj.removeClass(ratingObj.data("class"));
			ratingObj.addClass("none");
		}
	}
};