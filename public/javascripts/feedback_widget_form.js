!function( $ ) {

	$(function () {

		if(jQuery.browser.msie) jQuery("#feedback-widget-container").addClass("ie")

		$("select").select2();

		var $ticket_desc = $("#helpdesk_ticket_ticket_body_attributes_description_html"),
			proxy_placeholders = jQuery(".form-placeholder").find("input[type=text], textarea");

		jQuery.each(proxy_placeholders, function(i, item){
			var $item = jQuery(item);
			if($item.hasClass("name_field")) return;
			$item.attr("placeholder", "");
			$item.data("placeholder-proxy", $item.parents(".control-group").find(".control-label"))
			$item.data("placeholder-proxy").attr("for", $item.attr("id"))
			$item.data("placeholder-proxy").toggle(!$item.val());

			// console.log($item.parents(".control-group").find(".control-label").html())
			$item.on("keydown paste change", function(ev){
				var $item = jQuery(this);
				setTimeout(function() {
			        $item.data("placeholder-proxy").toggle(!$item.val());
			    }, 0);
			})
		})

		$ticket_desc.redactor({
			convertDivs: false, 
			autoresize:false, 
			buttons:['bold','italic','underline','|','unorderedlist', 'orderedlist',  '|','fontcolor', 'backcolor', '|' ,'link'],
			keyupCallback: function(e){
				var $item = $ticket_desc;
				setTimeout(function() {
			        $item.data("placeholder-proxy").toggle(!jQuery(".redactor_editor").text());
			    }, 0);
			}
		});

		$ticket_desc.data("placeholder-proxy").toggle(!jQuery(".redactor_editor").text());
		
		setTimeout(function() {
	 		jQuery("#fd_feedback_widget").validate({
				highlight: function(element, errorClass) {
					// Applying bootstraps error class on the container of the error element
					$(element).parents(".control-group").addClass(errorClass+"-group")
				},
				unhighlight: function(element, errorClass) {
					// Removed bootstraps error class from the container of the error element
					$(element).parents(".control-group").removeClass(errorClass+"-group")
				},
				onkeyup: false,
         		focusCleanup: true,
         		focusInvalid: false,
         		ignore:"select.nested_field:empty, .portal_url:not(:visible)",
				errorElement: "div", // Adding div as the error container to highlight it in red
	 		});
	 	},500);

	 	// USED in ticket form		    
		// Checking if the email is already present in the system
    	// If email is new requester then a "name" field will be shown to the user as an optional input in the request form
	    $("#helpdesk_ticket_email").focusout(function(){	    	
	    	var $this = $(this),
				ticket_email = $this.val(),
				email_path = $this.data("checkEmailPath"),
				toggle_name = function(enable){ 
					var _name_div = $("#name_field").find("input")
										.attr("disabled", !enable).parent()
					if(enable)
						_name_div.slideDown()
					else
						_name_div.slideUp()
				}

			if(email_path == "") return

			if(ticket_email.isValidEmail()){				
				$this.addClass("loading-right")

				$.ajax({ url: email_path+"?v="+ticket_email,
				  	success: function(data){
					    $this.removeClass("loading-right")
					    toggle_name(!data.user_exists)
					}
				})
			}else{
				toggle_name(false)
			}
		})

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

		jQuery('#takescreen-btn a').bind("click", function(ev){
			ev.preventDefault();

			screenshot_flag=0;
			jQuery('#takescreen-btn').hide();
			jQuery('#screenshot-wrap').show();

			if(!jQuery.browser.msie && !jQuery.browser.opera)
				jQuery('.flash').show();
		});
	});

}(window.jQuery);

var screenshot_flag=1;	

jQuery(window).bind("message", function(e) {
    var data = e.originalEvent.data; 
    loadCanvas(data);
});	

function remove_screenshot(){
	screenshot_flag=1;
	jQuery('.flash').hide();
	jQuery('#screenshot-wrap').hide();
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
    var canvas = document.getElementById("f-screenshot");
    var context = canvas.getContext("2d");
    // load image from data url
    var imageObj = new Image();
	    imageObj.onload = function() {
	    context.drawImage(this, 0, 0 , 300 , 220);
    };
    imageObj.src = dataURL;
    img_data = dataURL;
    // onchecked();
}

// Additional util methods for support helpdesk
// Extending the string protoype to check if the entered string is a valid email or not
String.prototype.isValidEmail = function(){
    return (/^((([a-z]|\d|[!#\$%&'\*\+\-\/=\?\^_`{\|}~]|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])+(\.([a-z]|\d|[!#\$%&'\*\+\-\/=\?\^_`{\|}~]|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])+)*)|((\x22)((((\x20|\x09)*(\x0d\x0a))?(\x20|\x09)+)?(([\x01-\x08\x0b\x0c\x0e-\x1f\x7f]|\x21|[\x23-\x5b]|[\x5d-\x7e]|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])|(\\([\x01-\x09\x0b\x0c\x0d-\x7f]|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF]))))*(((\x20|\x09)*(\x0d\x0a))?(\x20|\x09)+)?(\x22)))@((([a-z]|\d|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])|(([a-z]|\d|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])([a-z]|\d|-|\.|_|~|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])*([a-z]|\d|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])))\.)+(([a-z]|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])|(([a-z]|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])([a-z]|\d|-|\.|_|~|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])*([a-z]|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])))\.?$/i).test(this)
}

String.prototype.trim = function(){
    return this.replace(/^\s+|\s+$/g, '')
}