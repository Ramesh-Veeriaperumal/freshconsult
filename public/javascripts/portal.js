/*
 * @author venom
 */
 
!function( $ ) {

	$(function () {

		"use strict"

		//!PORTALCSS move this helper javascript to a util js
		String.prototype.sanitize_ids = function() {
		    return "#" + this.replace(' ', '').split(',').join(", #")
		};
		
		// Attaching dom ready events

		// Remote ajax for links
		$("a[data-remote]").live("click", function(ev){
			ev.preventDefault()

			// Setting the submit button to a loading state
			$(this).button("loading")

			var _o_data = $(this).data(),
				_self = $(this),
				_post_data = { 
					"_method" : $(this).data("method")
				}

			$.ajax({
				type: 'POST',
				url: this.href,
				data: _post_data,
				success: function(data){					
					$((_o_data.showDom||"").sanitize_ids()).show()
					$((_o_data.hideDom||"").sanitize_ids()).hide()
					$("#"+_o_data.update).html(_o_data.updateWithMessage || data)	

					// Resetting the submit button to its default state
					_self.button("reset")
					_self.html(_self.hasClass("active") ? 
									_o_data.buttonActiveLabel : _o_data.buttonInactiveLabel)

				}
			})
		})

		// Form validation any form append to the dom will be tested via live query and then be validated via jquery
		$("form[rel=validate]").livequery(function(ev){
			$("form[rel=validate]").validate({
				highlight: function(element, errorClass) {
					// Applying bootstraps error class on the container of the error element
					$(element).parent().parent().addClass(errorClass);
				},
				unhighlight: function(element, errorClass) {
					// Removed bootstraps error class from the container of the error element
					$(element).parent().parent().removeClass(errorClass);
				},
				errorElement: "div", // Adding div as the error container to highlight it in red
					submitHandler: function(form, btn) {
						// Setting the submit button to a loading state
						$(btn).button("loading")

						// IF the form has an attribute called data-remote then it will be submitted via ajax
						if($(form).data("remote"))
				  	   	$(form).ajaxSubmit({
				  	   		success: function(response, status){
				  	   			// Resetting the submit button to its default state
				  				$(btn).button("reset");

				  				// If the form has an attribute called update it will used to update the response obtained
				  	   			$("#"+$(form).data("update")).html(response)
				  	   		}
				  	   	})
					// For all other form it will be a direct page submission			  	
				  	else form.submit()
				}
			})
		})

	})

}(window.jQuery);