jQuery("document").ready(function(){
		setTimeout(function() {
	 		jQuery("#fd_feedback_widget").validate();
 	},500);

 	jQuery("#freshwidget-submit-frame").bind("load", function() {
 		if(jQuery("#freshwidget-submit-frame").contents().find("#ui-widget-container").length != 0) {
 			jQuery("#ui-widget-container").hide();
	 		jQuery("#ui-thanks-container").html(jQuery("#freshwidget-submit-frame").contents().find("#ui-widget-container").html());
	 		jQuery("#ui-thanks-container").show();
	 	}
 	});
 		
	
 	jQuery('#fd_feedback_widget').submit(function(ev) {
 		if (screenshot_flag==0) {
 			
			var img = img_data.replace("data:image/png;base64,","");
			var time = new Date();
			var name = String(time);		
			name = "Screen Shot_" + name ;
			name = name.replace(/:/g,"-");
			postscreenshot("data",img);
			postscreenshot("name",name);
		}
	});
});

var screenshot_flag=1;	

jQuery(window).bind("message", function(e) {
    var data = e.originalEvent.data; 
    loadCanvas(data);
});	

function remove_screenshot(){
	screenshot_flag=1;
	jQuery('.flash').hide();
	jQuery('.closeBtn').hide();
	jQuery('.screenshotpop').hide();
	jQuery('#takescreen-btn').show();
}

function postscreenshot(name,value){
	var fileref = document.createElement("input");
	fileref.setAttribute("type","hidden");
	fileref.setAttribute("name","screenshot["+name+"]");
	fileref.setAttribute("value", value);
	fileref.setAttribute("id", "uploadscreenshot");
	document.getElementById("fd_feedback_widget").appendChild(fileref);
}	

function loadCanvas(dataURL) {
    var canvas = document.getElementById("mycanvas");
    var context = canvas.getContext("2d");
    // load image from data url
    var imageObj = new Image();
    imageObj.onload = function() {
    context.drawImage(this, 0, 0 , 300 , 220);
    };
    imageObj.src = dataURL;
    img_data = dataURL;
    onchecked();
}
	        
function onchecked(){
	jQuery('#takescreen-btn').click( function(){
		screenshot_flag=0;
		jQuery('#takescreen-btn').hide();
		
		if(!jQuery.browser.msie)
			jQuery('.flash').show();

		jQuery('.closeBtn').show();
		jQuery('.screenshotpop').show();
	});
}	