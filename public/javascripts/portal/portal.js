/*
 * @author venom
 * Portal common page scripts
 */

jQuery.noConflict()
 
!function( $ ) {

	$(function () {

		"use strict"
		
		// Attaching dom ready events

		// Preventing default click & event handlers for disabled or active links
		$(".pagination, .dropdown-menu") 
			.find(".disabled a, .active a")
			.on("click", function(ev){
				ev.preventDefault()
				ev.stopImmediatePropagation()
			})
		
		// Remote ajax for links
		$("a[data-remote]").live("click", function(ev){
			ev.preventDefault()

			var _o_data = $(this).data(),
				_self = $(this),
				_post_data = { 
					"_method" : $(this).data("method")
				}

			if(!_o_data.loadonce){
				// Setting the submit button to a loading state
				$(this).button("loading")

				// A data-loading-box will show a loading box in the specified container
				$(_o_data.loadingBox||"").html("<div class='loading-box'></div>")

				$.ajax({
					type: _o_data.type || 'POST',
					url: this.href,
					data: _post_data,
					dataType: _o_data.responseType || "html",
					success: function(data){					
						$(_o_data.showDom||"").show()
						$(_o_data.hideDom||"").hide()
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
		$("a[data-method], button[data-method]").live("click", function(ev){
			ev.preventDefault()
			if($(this).data("remote")) return

			if($(this).data("confirm") && !confirm($(this).data("confirm"))) return

			var _form = $("<form class='hide' method='post' />")
							.attr("action", this.href)
							.append("<input type='hidden' name='_method' value='"+$(this).data("method")+"' />")
							.get(0).submit()			
		})

		// Data api for onclick showing dom elements
		$("a[data-show-dom], button[data-show-dom]").live("click", function(ev){
			ev.preventDefault()
			if($(this).data("remote")) return

			$($(this).data("showDom")).show()
		})

		// Data api for onclick hiding dom elements
		$("a[data-hide-dom], button[data-hide-dom]").live("click", function(ev){
			ev.preventDefault()
			if($(this).data("remote")) return

			$($(this).data("hideDom")).hide()
		})

		// Data api for onclick toggle of dom elements
		$("a[data-toggle-dom], button[data-toggle-dom]").live("click", function(ev){
			ev.preventDefault()
			if($(this).data("remote")) return

			if($(this).data("animated") != undefined)
				$($(this).data("toggleDom")).slideToggle()
			else	
				$($(this).data("toggleDom")).toggle()
		})

		// Data api for onclick change of html text inside the dom element
		$("[data-toggle-text]").live("click", function(ev){
			ev.preventDefault()
			if($(this).data("remote")) return

			var _oldText = $(this).data("toggleText"),
				_currentText = $(this).html()

			$(this)
				.data("toggleText", _currentText)
				.html(_oldText)
		})

		// Data api for onclick for show hiding a proxy input box to show inplace of a redactor or textarea
		$("input[data-proxy-for], a[data-proxy-for]").live("click", function(ev){
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
			$(this).validate({
				highlight: function(element, errorClass) {
					// Applying bootstraps error class on the container of the error element
					$(element).parent().parent().addClass(errorClass+"-group")
				},
				unhighlight: function(element, errorClass) {
					// Removed bootstraps error class from the container of the error element
					$(element).parent().parent().removeClass(errorClass+"-group")
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
			  				$(btn).button("reset")

			  				// If the form has an attribute called update it will used to update the response obtained
			  	   			$("#"+$(form).data("update")).html(response)
			  	   		}
			  	   	})
					// For all other form it will be a direct page submission			  	
				  	else form.submit()
				}
			})
		})
	
		// Live query utility
		$("[data-live-query]").livequery(function(ev){
			switch($(this).data("liveQuery")){
				// Adds custom-select class that will in-turn call another live query 
				// that will init select2 plugin for all the select boxes in the form
				case "select-boxes":
					$(this).find("select").addClass("custom-select")
				break
			}
		})

	})

}(window.jQuery)