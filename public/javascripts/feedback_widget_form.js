!function( $ ) {

	$(function () {

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

			$item.on("keydown paste change", function(ev){
				var $item = jQuery(this);
				setTimeout(function() {
			        $item.data("placeholder-proxy").toggle(!$item.val());
			    }, 0);
			})
		})


		$ticket_desc.redactor({
			convertDivs: false,
			autoresize: false,
			mobile: false,
			buttons:['bold','italic','underline','|','unorderedlist', 'orderedlist',  '|','fontcolor', 'backcolor', '|' ,'link'],
			keyupCallback: function(e){
				var $item = $ticket_desc;
				setTimeout(function() {
			        $item.data("placeholder-proxy").toggle(!jQuery(".redactor_editor").text());
			    }, 0);
			}
		});

		if(inMobile()){
			$(".form-widget").addClass("form-mobile");
			$("#helpdesk_ticket_ticket_body_attributes_description_html").removeClass("required_redactor").addClass("required");
		}

		var $placeholder_proxy = $ticket_desc.data("placeholder-proxy")

		if($placeholder_proxy != undefined)
			$placeholder_proxy.toggle(!jQuery(".redactor_editor").text());

		$.urlParam = function(name){
			var results = new RegExp('[\?&]' + name + '=([^&#]*)').exec(window.location.href);
			return results[1] || 0;
		};

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
			submitHandler: function(form, btn) {
				if (screenshot_flag==0) {
					var img = img_data.replace("data:image/png;base64,","");
					var time = new Date();
					var name = String(time);
					name = "Screen Shot_" + name ;
					name = name.replace(/:/g,"-");
					postscreenshot("data",img);
					postscreenshot("name",name);
				}

				hide_captcha_error();
				var captcha_response = $('#recaptcha_response_field').val();
				if((captcha_response !== undefined) && (captcha_response.length === 0)){
					show_captcha_error();
					return false;
				}

				// Setting the submit button to a loading state
				$("#helpdesk_ticket_submit").button("loading")

	  	    	// For all other form it will be a direct page submission
	  	    	//form.submit()
						$(form).ajaxSubmit({
							dataType: 'json',
							success: function(response, status){
								// Resetting the submit button to its default state
							if(response.success === true){
								// show thank you message
								var thankyou_url = '/widgets/feedback_widget/thanks?widgetType=';
								thankyou_url += $.urlParam('widgetType');
								if($('#submit_message').val()) {
									thankyou_url += "&submit_message=" + encodeURI($('#submit_message').val());
								}

								thankyou_url += "&retainParams=" + encodeURI($('#retainParams').val());
								window.location = thankyou_url;
							}else {
								$('#errorExplanation').removeClass('hide');
								$('#feedback_widget_error').html(response.error);
								if(typeof Recaptcha != "undefined") {
									Recaptcha.reload();
								}

							}
							$("#helpdesk_ticket_submit").button("reset");

							},
							error:function(err){
								console.log(err);
								$("#helpdesk_ticket_submit").button("reset");
							}
						})

			}
 		});

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
					if(enable){
						_name_div.slideDown()
						if($("input[name='helpdesk_ticket[name]']").data('userName')){
							jQuery("input[name='helpdesk_ticket[name]']").val($("input[name='helpdesk_ticket[name]']").data('userName'));
						}
					}
					else{
						_name_div.slideUp()
					}
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


		jQuery('#takescreen-btn a').on("click", function(ev){
			// sending message to the parent window
			parent.postMessage('screenshot',"*");
			ev.preventDefault();
			screenshot_flag=0;

			
		});

		// Uses the date format specified in the data attribute [date-format], else the default one 'yy-mm-dd'
    jQuery("input.datepicker_popover").livequery(function() {
      var dateFormat = 'yy-mm-dd';
      if(jQuery(this).data('date-format')) {
        dateFormat = jQuery(this).data('date-format');
      }
      jQuery(this).datepicker({
        dateFormat: dateFormat,
        changeMonth:true,
        changeYear:true,
      });
      if(jQuery(this).data('showImage')) {
        jQuery(this).datepicker('option', 'showOn', "both" );
        jQuery(this).datepicker('option', 'buttonText', "<i class='ficon-date'></i>" );
      }
    });

	});

}(window.jQuery);

var screenshot_flag=1;

jQuery(window).on("message", function(e) {
    var data = e.originalEvent.data;
    if(data.type=="screenshot")
    {
    	var loaded=loadCanvas(data.img);
    if(loaded)
    {
    	console.log('image loaded');
    	jQuery('#takescreen-btn').hide();
			jQuery('#screenshot-wrap').show();
			if(!jQuery.browser.msie && !jQuery.browser.opera)
				jQuery('.flash').show();
    }
    }
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
    context.clearRect(0, 0, canvas.width, canvas.height);
    // load image from data url
    var imageObj = new Image();
	    imageObj.onload = function() {
	    context.drawImage(this, 0, 0 , 300 , 220);
    };
    imageObj.src = dataURL;
    img_data = dataURL;
	return true;
}

// Additional util methods for support helpdesk
// Extending the string protoype to check if the entered string is a valid email or not
String.prototype.isValidEmail = function(){
    return (/^((([a-z]|\d|[!#\$%&'\*\+\-\/=\?\^_`{\|}~]|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])+(\.([a-z]|\d|[!#\$%&'\*\+\-\/=\?\^_`{\|}~]|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])+)*)|((\x22)((((\x20|\x09)*(\x0d\x0a))?(\x20|\x09)+)?(([\x01-\x08\x0b\x0c\x0e-\x1f\x7f]|\x21|[\x23-\x5b]|[\x5d-\x7e]|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])|(\\([\x01-\x09\x0b\x0c\x0d-\x7f]|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF]))))*(((\x20|\x09)*(\x0d\x0a))?(\x20|\x09)+)?(\x22)))@((([a-z]|\d|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])|(([a-z]|\d|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])([a-z]|\d|-|\.|_|~|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])*([a-z]|\d|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])))\.)+(([a-z]|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])|(([a-z]|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])([a-z]|\d|-|\.|_|~|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])*([a-z]|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])))\.?$/i).test(this)
}

String.prototype.trim = function(){
    return this.replace(/^\s+|\s+$/g, '')
}

function show_captcha_error(){
	jQuery('#helpdesk_ticket_captcha-error').removeClass('hide');
	jQuery('#captcha_wrap').addClass('recaptcha-error');
}

function hide_captcha_error(){
	jQuery('#helpdesk_ticket_captcha-error').addClass('hide');
	jQuery('#captcha_wrap').removeClass('recaptcha-error');
}
