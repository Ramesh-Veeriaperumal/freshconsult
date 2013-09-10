/*
 * @author venom
 * Portal specific ui-elements initialization scripts
 */
 
!function( $ ) {

	if ((portal['preferences']['nonResponsive'] == "true") || Modernizr.mq('only screen and (min-width: 980px)')) {
		layoutResize(".main", ".sidebar")
	}

	$(function () {

		"use strict"

		// USED in New ticket form
		// Event for fetching agents based on the groups present
		$("#helpdesk_ticket_group_id")
		    .on("change", function(e){
		    	var _agent_ui = $("#helpdesk_ticket_responder_id")

		    	if(!_agent_ui.get(0)) return

		      	_agent_ui.html("<option value=''>...</option>")

			    $.post( '/helpdesk/commons/group_agents/'+$(this).val(),
	        		function(data){
						_agent_ui.html(data);
					});
		    });

		// USED in New ticket form		    
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

		// USED in New ticket form and Add cc email for ticket details page
		var _static_cc_emails_opts = {
			data: [],
			multiple: true,
			tokenSeparators: [",", " "],
			formatNoMatches: function () { return "Add multiple cc emails seperated by \",\""; },
			createSearchChoice: function(term, data) {
									if(jQuery(data).filter(function() { return this.text.localeCompare(term)===0; }).length===0) { 
										if(term.isValidEmail())
											return {id:term, text:term}
									} 
								},
		    initSelection: 	function (element, callback) {
						        var data = [];	        
						        $(element.val().split(",")).each(function(i, term) {
						            data.push({id: term, text: term});
						        });
						        callback(data);
						    }
		}
		// This is used in the place when the user can cc anybody
		$("input#cc_emails").select2(_static_cc_emails_opts)

		var _closed_list_cc_emails_opts = {
			tokenSeparators: [",", " "],
			formatNoMatches: function () { return ""; }
		}
		// This is used in the place when the user can cc only people from his company
		$("select#cc_emails").select2(_closed_list_cc_emails_opts)

		$("select.custom-select").livequery(function(){			
			$(this).select2($.extend({ minimumResultsForSearch: 10, allowClear: true }, $(this).data()))
		})

		// Hacks for overriding Bootstrap defaults
		// Changing the default loading button text
		$.fn.button.defaults = { loadingText: 'Please wait...'  }

		// Adding Dependant rule for password
		if($("#password_confirmation").get(0)){
			$("#password_confirmation").rules("add", {  
		        equalTo: "#password",
		        messages: {
				   equalTo: "Should be same as Password"
				}
	        });
		}

		// To show forgot password if its available in the page
		if(/forgot_password/.test(window.location.hash))
			$("#forgot_password").trigger('click')

		// Page search autocompelete
		window['portal-search-boxes'] = $( "input[rel=page-search]" )
		if(window['portal-search-boxes'].get().size() > 0){
			window['portal-search-cache'] = {}
			window['portal-search-boxes'].autocomplete({
	        	minLength: 2,
	        	source: function( request, response ) {
	                var term = request.term.trim(),
	                	$element = this.element,
	                	cache = window['portal-search-cache'],
	                	url = $element.parents('form:first').attr('action') || "/support/search.json"

	                if( term in cache || term == '' ) {
	                    response( cache[ term ] )
	                    return
	                }

	                request['max_matches'] = $element.data("maxMatches")

	                $.getJSON(url, request, function( data, status, xhr ) {
						window['portal-search-cache'][ term ] = data
						response( data )
	                });
	            },
	            focus: function( event, ui ) { event.preventDefault() }
	        })
	        .on( "autocompleteselect", function( event, ui ) { window.location = ui.item.url } )
			
			window['portal-search-render-ui'] = function( ul, item ) {
	            return $( "<li>" )
	                .data( "item.autocomplete", item )
	                .append("<a href='"+item.url+"'>" + item.title + "</a> ")
	                .append('<span class="label label-small label-light">'+ item.group +'</span>')
	                // .append('<div>'+ item.desc +'</div>')
	                .addClass(item.type.toLowerCase()+'-item')
	                .appendTo( ul )
	        }

			$.each(window['portal-search-boxes'], function(i, searchItem){
				$(searchItem).data( "autocomplete" )._renderItem = window['portal-search-render-ui']
			})
    	}

        // mobile search box focus style
        if (Modernizr.mq('only screen and (max-width: 768px)')) {
			$(".help-center input[rel='page-search']").focus(function () {
				$(".hc-search").addClass("onfocus-mobile")
				$(".hc-nav").hide('fast')
			}).blur(function(){
		    	$(".hc-search").removeClass("onfocus-mobile")
		    	$(".hc-nav").show()
			})
		}


		// Recapcha fix for multiple forms
		// Fix for reCapcha !!! should be removed if it is removed
		window['portal-recaptcha'] = $('.recaptcha-control')

		if(window['portal-recaptcha'].size() > 1){			
	    	$.each(window['portal-recaptcha'], function(i, item){
	    		if(i > 0){
		    		$(item).find("#recaptcha_widget_div")
		    			.show()
		    			.html(window['portal-recaptcha']
		    				.first()
		    				.find("#recaptcha_widget_div")
		    				.clone(true, true))
		    	}
	    	})
	    }

	    

	})

}(window.jQuery);