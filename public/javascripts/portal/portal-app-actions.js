/*
 * @author venom
 * Portal specific ui-elements scripts
 */
 
!function( $ ) {

	// If no sidebar is present make the main content to stretch to full-width
	if(!$(".sidebar").get(0)) $(".main").removeClass("main")

	$(function () {

		"use strict"
		
		// !USED in New ticket form
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

		// !USED in New ticket form		    
		// Checking if the email is already present in the system
    	// If email is new requester then a name field will be shown to the user as an optional input in the request form
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
				$this.addClass("loading")

				$.ajax({ url: email_path+"?v="+ticket_email,
				  	success: function(data){
					    $this.removeClass("loading")
					    toggle_name(!data.user_exists)
					}
				})
			}else{
				toggle_name(false)
			}
		})

		// !USER in New ticket form and Add cc email for ticket details page
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
	})

}(window.jQuery);

// Additional util methods for support helpdesk

// Extending the string protoype to check if the entered string is a valid email or not
String.prototype.isValidEmail = function(){
	return (/^((([a-z]|\d|[!#\$%&'\*\+\-\/=\?\^_`{\|}~]|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])+(\.([a-z]|\d|[!#\$%&'\*\+\-\/=\?\^_`{\|}~]|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])+)*)|((\x22)((((\x20|\x09)*(\x0d\x0a))?(\x20|\x09)+)?(([\x01-\x08\x0b\x0c\x0e-\x1f\x7f]|\x21|[\x23-\x5b]|[\x5d-\x7e]|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])|(\\([\x01-\x09\x0b\x0c\x0d-\x7f]|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF]))))*(((\x20|\x09)*(\x0d\x0a))?(\x20|\x09)+)?(\x22)))@((([a-z]|\d|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])|(([a-z]|\d|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])([a-z]|\d|-|\.|_|~|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])*([a-z]|\d|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])))\.)+(([a-z]|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])|(([a-z]|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])([a-z]|\d|-|\.|_|~|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])*([a-z]|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])))\.?$/i).test(this)
}