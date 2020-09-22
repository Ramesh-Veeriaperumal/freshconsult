! function($) {

    $(function() {

    $("select").select2({
      minimumResultsForSearch: 5 // at least 5 results must be displayed
		});
    var $ticket_desc = $("#helpdesk_ticket_ticket_body_attributes_description_html"),
        proxy_placeholders = jQuery(".form-placeholder").find("input[type=text], input[type=email], textarea");

    jQuery.each(proxy_placeholders, function(i, item) {
        var $item = jQuery(item);
        if ($item.hasClass("name_field")) return;
        $item.attr("placeholder", "");
        $item.data("placeholder-proxy", $item.parents(".control-group").find(".control-label"))
        $item.data("placeholder-proxy").attr("for", $item.attr("id"))
        $item.data("placeholder-proxy").toggle(!$item.val());

        $item.on("keydown paste change", function(ev) {
            var $item = jQuery(this);
            setTimeout(function() {
                $item.data("placeholder-proxy").toggle(!$item.val());
            }, 0);
        })
    })
    jQuery(document).on('focus', '.redactor_editor', function() {
      jQuery('.default_description').addClass('default_description_focus');
      jQuery('.attach-wrapper').addClass('attach-wrapper-focus');
      jQuery('#helpdesk_ticket_ticket_body_attributes_description_html-error').css({'display':'none'})
    });
    jQuery(document).on('blur', '.redactor_editor', function() {
      jQuery('.default_description').removeClass('default_description_focus');
      jQuery('.attach-wrapper').removeClass('attach-wrapper-focus');
      if(!$ticket_desc.data('redactor').isNotEmpty()){
        jQuery('#helpdesk_ticket_ticket_body_attributes_description_html-error').css({'display':'block'})
      }
    });
    $ticket_desc.redactor({
      convertDivs: false,
      autoresize: false,
      mobile: false,
      buttons: ['bold', 'italic', 'underline', '|', 'unorderedlist', 'orderedlist', '|', 'fontcolor', 'backcolor', '|', 'link'],
      popover: true,
      keyupCallback: function(ele,event) {
        var $item = $ticket_desc;
        var w = ele.$el.data('focusIncount') || 0
        ele.$el.data('focusIncount', w + 1)
        var count=ele.$el.data('focusIncount');
        if(event.which===9 && count > 1){
          ele.$editor.blur();
          ele.$el.data('focusIncount', 0)
        }
        setTimeout(function() {
          $item.data("placeholder-proxy").toggle(!jQuery(".redactor_editor").text());
        }, 0);
      }
    });

    if (inMobile()) {
        $(".form-widget").addClass("form-mobile");
        $("#helpdesk_ticket_ticket_body_attributes_description_html").removeClass("required_redactor").addClass("required");
    }

		var $placeholder_proxy = $ticket_desc.data("placeholder-proxy")

		if($placeholder_proxy != undefined)
			$placeholder_proxy.toggle(!jQuery(".redactor_editor").text());

		$.urlParam = function(name){
			var results = new RegExp('[\?&]' + name + '=([^&#]*)').exec(window.location.href);
			if(results != null && results.length == 2){
				return results[1];	
			} else{
				return 0;
			}
		};

 		jQuery("#fd_feedback_widget").validate({
			highlight: function(element, errorClass) {
				// Applying bootstraps error class on the container of the error element
				$(element).parents(".control-group").addClass(errorClass+"-group")
			},
			unhighlight: function(element, errorClass) {
        if($(element).parents(".control-group").hasClass('custom_checkbox')){
            $(element).parents(".control-group").find('.error').remove();
        }
				// Removed bootstraps error class from the container of the error element
				$(element).parents(".control-group").removeClass(errorClass+"-group")
			},
      errorPlacement:function(error,ele){
          if(jQuery(ele).hasClass('checkbox')){
              ele.parent().parent().parent().find(error).remove();
              error.addClass('checkbox-error-message').insertAfter(ele.closest("div"));
          }else{
              error.insertAfter(ele);
          }
      },
			onkeyup: false,
     		focusCleanup: true,
     		focusInvalid: false,
     		messages : {	
     			'helpdesk_ticket[email]': I18n.t('validation.email'),
     			'helpdesk_ticket[subject]': I18n.t('validation.required'),
     			'helpdesk_ticket[ticket_body_attributes][description_html]': I18n.t('validation.required')
     		},
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
				$("#helpdesk_ticket_submit").button("loading");

        //converting form into form data to support Attachments
        var formData = new FormData(form);

        // For all other form it will be a direct page submission
        //form.submit()
        $.ajax({
          url     : form.action,
          type    : form.method,
          data    : formData,
          // contentType flag set to false, forcing jQuery not to add a Content-Type header for you, otherwise, the boundary string will be missing from it.
          // processData flag set to false, to avoid convertion FormData into a string
          processData: false,
          contentType: false,
          dataType: 'json',
          // Resetting the submit button to its default state
          success : function (response, status) {
            if(response.success === true) {
              // show thank you message
              var thankyou_url = '/widgets/feedback_widget/thanks?widgetType=';
              thankyou_url += $.urlParam('widgetType');
              if($('#submit_message').val()) {
                thankyou_url += "&submit_message=" + encodeURIComponent($('#submit_message').val());
              }

              thankyou_url += "&retainParams=" + encodeURIComponent($('#retainParams').val());
              window.location = thankyou_url;
              //resize parent frame for popup widget
              if(!jQuery(".feedback-wrapper").hasClass("embedded-wrapper") && jQuery('#feedback-suggest').hasClass('feedback-suggest-change')){
                parent.postMessage('hidesearch', "*");
                jQuery('.feedback-wrapper ').addClass('feedback-wrapper-change-close');
                jQuery('#feedback-suggest').addClass('animate-suggest-close');
                window.setTimeout(function(){
                   jQuery('#feedback-suggest').removeClass('animate-suggest-close feedback-suggest-change');
                   jQuery('.feedback-wrapper ').removeClass('feedback-wrapper-change-close feedback-wrapper-change');
                },300);
              }

              jQuery('#fs-input').val('');
            } else {
              $('#errorExplanation').removeClass('hide');
              $('#feedback_widget_error').html(response.error);
              if(typeof Recaptcha != "undefined") {
                Recaptcha.reload();
              }
            }
            $("#helpdesk_ticket_submit").button("reset");
          },
          error : function (response, data)
          {
            $('#errorExplanation').removeClass('hide');
            $('#feedback_widget_error').html(JSON.parse(response.responseText).error);
              if(typeof Recaptcha != "undefined") {
                Recaptcha.reload();
              }
            $("#helpdesk_ticket_submit").button("reset");
          }
        });
			}
 		});

	 	jQuery("#freshwidget-submit-frame").bind("load", function() {
	 		if(jQuery("#freshwidget-submit-frame").contents().find("#ui-widget-container").length != 0) {
	 			jQuery("#ui-widget-container").hide();
		 		jQuery("#ui-thanks-container").html(jQuery("#freshwidget-submit-frame").contents().find("#ui-widget-container").html());
		 		jQuery("#ui-thanks-container").show();
		 	}
	 	});


		jQuery('#takescreen-btn .ficon-camera').on("click", function(ev){
			// sending message to the parent window
			jQuery("#screenshot-value").hide();
			jQuery("#screenshot-loader").show();
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
            beforeShow: function() {
                setTimeout(function(){
                    jQuery('.ui-datepicker').css('z-index', 1051);
                }, 0);
            }
          });
          jQuery(this).on('change', function() {
              $(this).trigger('blur');
          });
          if(jQuery(this).data('showImage')) {
            jQuery(this).datepicker('option', 'showOn', "both" );
            jQuery(this).datepicker('option', 'buttonText', "<i class='ficon-date'></i>" );
          }
          	// custom clear button
    		var clearButton =  jQuery(this).siblings('.dateClear');
    		if(clearButton.length === 0) {
    			 clearButton = jQuery('<span class="dateClear"><i class="ficon-cross" ></i></div>');
    			jQuery(this).after(clearButton);
    		}
    		if(jQuery(this).val().length === 0) {
    			clearButton.hide();
    		}
    		jQuery(this).on("change",function(){
    			if(jQuery(this).val().length === 0) {
    				clearButton.hide();
    			}
    			else {
    				clearButton.show();
    			}

    		});
    		clearButton.on('click', function(e) {
    			 jQuery(this).siblings('input.date').val("");
    			 jQuery(this).hide(); 
    		 });
    		// clear button ends
        });
    });
}(window.jQuery);

var screenshot_flag = 1;

jQuery(window).on("message", function(e) {
    var data = e.originalEvent.data;
    if (data.type == "screenshot") {
        var loaded = loadCanvas(data.img);
        if (loaded) {
            jQuery('#takescreen-btn').hide();
            jQuery('#screenshot-wrap,#screenshotRemove').show();
            if (!jQuery.browser.msie && !jQuery.browser.opera)
                jQuery('.flash').show();
        }
    }
});

function remove_screenshot() {
    jQuery("#screenshot-value").show();
    jQuery("#screenshot-loader").hide();
    screenshot_flag = 1;
    jQuery('.flash').hide();
    jQuery('#screenshot-wrap,#screenshotRemove').hide();
    jQuery('#takescreen-btn').show();
}

function postscreenshot(name, value) {
    var fileref = document.createElement("input");
    fileref.setAttribute("type", "hidden");
    fileref.setAttribute("name", "screenshot[" + name + "]");
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
        context.drawImage(this, 0, 0, 300, 220);
    };
    imageObj.src = dataURL;
    img_data = dataURL;
    return true;
}

// Additional util methods for support helpdesk
// Extending the string protoype to check if the entered string is a valid email or not
String.prototype.isValidEmail = function() {
    return (/^((([a-z]|\d|[!#\$%&'\*\+\-\/=\?\^_`{\|}~]|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])+(\.([a-z]|\d|[!#\$%&'\*\+\-\/=\?\^_`{\|}~]|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])+)*)|((\x22)((((\x20|\x09)*(\x0d\x0a))?(\x20|\x09)+)?(([\x01-\x08\x0b\x0c\x0e-\x1f\x7f]|\x21|[\x23-\x5b]|[\x5d-\x7e]|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])|(\\([\x01-\x09\x0b\x0c\x0d-\x7f]|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF]))))*(((\x20|\x09)*(\x0d\x0a))?(\x20|\x09)+)?(\x22)))@((([a-z]|\d|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])|(([a-z]|\d|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])([a-z]|\d|-|\.|_|~|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])*([a-z]|\d|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])))\.)+(([a-z]|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])|(([a-z]|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])([a-z]|\d|-|\.|_|~|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])*([a-z]|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])))\.?$/i).test(this)
}

String.prototype.trim = function() {
    return this.replace(/^\s+|\s+$/g, '')
}

function show_captcha_error() {
    jQuery('#helpdesk_ticket_captcha-error').removeClass('hide');
    jQuery('#captcha_wrap').addClass('recaptcha-error');
}

function hide_captcha_error() {
    jQuery('#helpdesk_ticket_captcha-error').addClass('hide');
    jQuery('#captcha_wrap').removeClass('recaptcha-error');
}
