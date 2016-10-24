/*
 * @author venom
 * Portal common page scripts
 */

!function( $ ) {

	if (!!navigator.userAgent.match(/^(?=.*\bTrident\b)(?=.*\brv\b).*$/)){
	  $.browser = { msie: true, version: "11" };
	}

	if($.browser.msie) $("body").addClass("ie")

	$(function () {

		"use strict"
		
		// Attaching dom ready events
		$(document).ready(function(){
			$('[rel=remote]').trigger('afterShow');

			//Loop through all the images
			// Get their orig dims.
			// Check the current aspect ratio (outerWidth)
			// If diff, set the height
			if( portal['preferences']['nonResponsive'] != "true" ) {
				$(window).on('resize', function () {
					$("[rel='image-enlarge'] img").each(function (i) {
						var img = $(this);
						$("<img/>")
					    .attr("src", img.attr("src"))
					    .load(function() {
					    	var originalWidth = this.width, 
					    		originalHeight = this.height, 
					    		outerWidth = img.outerWidth(),
					    		outerHeight = img.outerHeight(),
					    		originalAspectRatio = originalWidth / originalHeight,
					    		aspectRatio = outerWidth / outerHeight;

							  if(aspectRatio !== originalAspectRatio) {
							  	img.outerHeight(outerWidth/originalAspectRatio);

								if(!img.parent('a').get(0)) {
									img.wrap(function(){
										return "<a target='_blank' class='image-enlarge-link' href='" + this.src + "'/>";
									});
								}
							  }
						    });
					});
				}).trigger('resize');
			}
		})
	
		// Preventing default click & event handlers for disabled or active links
		$(".pagination, .dropdown-menu")
			.find(".disabled a, .active a")
			.on("click", function(ev){
				ev.preventDefault()
				ev.stopImmediatePropagation()
			})

		// Remote ajax for links
		$(document).on("click", ".a-link[data-remote], a[data-remote]", function(ev){
			ev.preventDefault()

			var _o_data = $(this).data(),
				_self = $(this),
				_post_data = {
					"_method" : $(this).data("method") || "get"
				}

			if(_o_data.confirm && !confirm(_o_data.confirm)) return

			if(!_o_data.loadonce){
				// Setting the submit button to a loading state
				if (_o_data.noLoading) {
					$(this).addClass('disabled');
				} else {
					$(this).button("loading")
				}	

				// A data-loading-box will show a loading box in the specified container
				$(_o_data.loadingBox||"").html("<div class='loading loading-box'></div>")

				$.ajax({
					type: _o_data.type || 'POST',
					url: this.href || _o_data.href,
					data: _post_data,
					dataType: _o_data.responseType || "html",
					success: function(data){		
						$(_o_data.showDom||"").show()
						$(_o_data.hideDom||"").hide()
						$(_o_data.toggleDom||"").toggle()
						$(_o_data.update||"").html(_o_data.updateWithMessage || data)	

						// Executing any unique dom related callback
						if(_o_data.callback != undefined)
							window[_o_data.callback](data)

						// Resetting the submit button to its default state
						_self.button("reset")
						_self.html(_self.hasClass("active") ? 
										_o_data.buttonActiveLabel : _o_data.buttonInactiveLabel)

					}
				})
			}else{
				$(_o_data.showDom||"").show()
				$(_o_data.hideDom||"").hide()
			}
		})

		// Data api for rails button submit with method passing
		$(document).on("click", "a[data-method], button[data-method]", function(ev){
			ev.preventDefault()
			if($(this).data("remote")) return

			if($(this).data("confirm") && !confirm($(this).data("confirm"))) return

			var _form = $("<form class='hide' method='post' />")
							.attr("action", this.href)
							.append("<input type='hidden' name='_method' value='"+$(this).data("method")+"' />")
							.appendTo("body");
							add_csrf_token(_form);
							_form.get(0).submit();
		})

		// Data api for onclick showing dom elements
		$(document).on("click", "a[data-show-dom], button[data-show-dom]", function(ev){
			ev.preventDefault()
			if($(this).data("remote")) return

			$($(this).data("showDom")).show()
		})

		// Data api for onclick hiding dom elements
		$(document).on("click", "a[data-hide-dom], button[data-hide-dom]", function(ev){
			ev.preventDefault()
			if($(this).data("remote")) return

			$($(this).data("hideDom")).hide()
		})

		// Data api for onclick toggle of dom elements
		$(document).on("click", "a[data-toggle-dom], button[data-toggle-dom]", function(ev){
			ev.preventDefault()
			if($(this).data("remote")) return

			if($(this).data("animated") != undefined)
				$($(this).data("toggleDom")).slideToggle()
			else	
				$($(this).data("toggleDom")).toggle()
		})

		$("[data-toggle='tooltip']").tooltip({ live: true });

		// Data api for onclick change of html text inside the dom element
		$(document).on("click", "[data-toggle-text]", function(ev){
			ev.preventDefault()
			if($(this).data("remote")) return

			var _oldText = $(this).data("toggleText"),
				_currentText = $(this).html()

			$(this)
				.data("toggleText", _currentText)
				.html(_oldText)
		})

		// Data api for onclick for show hiding a proxy input box to show inplace of a redactor or textarea
		$(document).on("click", "input[data-proxy-for], a[data-proxy-for]", function(ev){
			var proxyDom = $(this).data("proxyFor")

			// Checking if the clicked element is a link so that the 
			// proper input element can be triggered
			if(this.nodeName.toLowerCase() == 'a'){
				// !PORTALCSS REFACTOR The below call may be too expensive need to think of better way
				jQuery("input[data-proxy-for="+proxyDom+"]").trigger("click") 
				return
			}

			ev.preventDefault()			

			$(this).hide()

			// Getting if there is any textarea in the proxy div
			var _textarea = $(proxyDom)
								.show()
								.find("textarea")

            // Setting the focus to the editor if it is redactor with a pre check for undefined
			if(_textarea.getEditor()) _textarea.getEditor().focus()
		})		

		// Form validation any form append to the dom will be tested via live query and then be validated via jquery
		$("form[rel=validate]").livequery(function(ev){
			var config = {
				errorPlacement: function(error, element) {
		          if (element.prop("type") == "checkbox")
		            error.insertAfter(element.parent());
		          else
		            error.insertAfter(element);
		        },
				highlight: function(element, errorClass) {
					// Applying bootstraps error class on the container of the error element
					$(element).parents('.control-group').addClass(errorClass+"-group")
				},
				unhighlight: function(element, errorClass) {
					// Removed bootstraps error class from the container of the error element
					$(element).parents('.control-group').removeClass(errorClass+"-group")
				},
				onkeyup: false,
         		focusCleanup: true,
         		focusInvalid: false,
         		ignore:"select.nested_field:empty, .portal_url:not(:visible)",
				errorElement: "div", // Adding div as the error container to highlight it in red
				submitHandler: function(form, btn) {
					// Setting the submit button to a loading state
					$(btn).button("loading")

					// IF the form has an attribute called data-remote then it will be submitted via ajax
					if($(form).data("remote")){
				  	   	$(form).ajaxSubmit({
				  	   		success: function(response, status){
				  	   			// Resetting the submit button to its default state
				  				$(btn).button("reset")

				  				// If the form has an attribute called update it will used to update the response obtained
				  	   			$("#"+$(form).data("update")).html(response)
				  	   		}
				  	   	})
			  	    }else{
			  	    	// For all other form it will be a direct page submission			  	
			  	    	add_csrf_token(form)

			  	    	// Nullifies the form data changes flag, which is checked to prompt the user before leaving the page.
        				$(form).data('formChanged', false);

			  	    	form.submit()
			  	    }
				}
			};

				jQuery.validator.addClassRules("date", {
				date: false
				});			


		$(this).validate(config);
		})
		
		var layzr;
		$(".image-lazy-load img").livequery(
			function(){
				layzr = new Layzr({
					container: null,
					selector: '.image-lazy-load img',
					attr: 'data-src',
					retinaAttr: 'data-src-retina',
					hiddenAttr: 'data-layzr-hidden',
					threshold: 0,
					callback: function(){
						$(".image-lazy-load img").css('opacity' , 1);
					}
				});
			},
			function() {
				layzr._destroy()
			}
		); 		
		
		// If there are some form changes that is unsaved, it prompts the user to save before leaving the page.
		$(window).on('beforeunload', function(ev){
			var form = $('.form-unsaved-changes-trigger');
			if(form.data('formChanged')) {
				ev.preventDefault();
				return customMessages.confirmNavigate;
			}
		});
		
		$('.form-unsaved-changes-trigger').on('change', function() {
			$(this).data('formChanged', true);
		});

    	// Uses the date format specified in the data attribute [date-format], else the default one 'yy-mm-dd'
		$("input.datepicker_popover").livequery(function() {

		// clear button ends
		var dateFormat = 'yy-mm-dd';
  if(jQuery(this).data('dateFormat')) {
    dateFormat = jQuery(this).data('dateFormat');
  }
// Cloning date element to process in ISO format
	var clone_date = jQuery(this).clone().removeAttr('class');
	var idForCloneElement = jQuery(this).prop("id");
	  clone_date.attr('id', 'clone_'+idForCloneElement).appendTo(this);
	jQuery(this).removeAttr('name');
		if((jQuery(this).val())==""){
	  	jQuery('#'+idForCloneElement).attr('data-initial-val', 'empty');}
	  	else{
	  	jQuery('#'+idForCloneElement).attr('data-initial-val', (jQuery(this).val()));}
		jQuery('#clone_'+idForCloneElement).hide();

	jQuery(this).datepicker({
    dateFormat: dateFormat,
    changeMonth: true,
    changeYear: true,
    altField: '#clone_'+idForCloneElement,
    altFormat: 'yy-mm-dd'
  });

	if((jQuery('#'+idForCloneElement).data('initial-val'))!="empty")
	{
	var getDateVal = (jQuery('#'+'clone_'+idForCloneElement).val());
	var DateVal = new Date(getDateVal);
	jQuery('#'+idForCloneElement).datepicker('setDate', DateVal);
}


   if(jQuery(this).data('showImage')) {
        jQuery(this).datepicker('option', 'showOn', "both" );
        jQuery(this).datepicker('option', 'buttonText', "<span class='icon-calendar'></span>" );
      }
      // custom clear button
  var clearButton =  jQuery(this).siblings('.dateClear');
  if(clearButton.length === 0) {
     clearButton = jQuery('<span class="dateClear" title="Clear Date"><i class="ficon-cross" ></i></div>');
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
     jQuery('#'+'clone_'+idForCloneElement).val("");
   });
		});

		$('[data-toggle=tooltip]').livequery(function() {
			$(this).tooltip();
		})

		$('body').on('afterShow', '[rel=remote]', function(ev) {
			var _self = $(this);
			if(!_self.data('loaded')) {
				_self.append("<div class='loading loading-box'></div>");
				_self.load(_self.data('remoteUrl'), function(){
					_self.data('loaded', true);
					_self.trigger('remoteLoaded');
				});
			}
		});
	})

}(window.jQuery);
