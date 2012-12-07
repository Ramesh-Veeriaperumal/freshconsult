/*
 * @author venom
 * Portal specific ui-elements scripts
 */

jQuery.noConflict()
 
!function( $ ) {

	$(function () {

		"use strict"
		
		// !USED in New ticket form 
		// whenever a group is changed it will fetch the list of agent in that group 
		// So that it will be made available when selecting an agent
		// Needed attributes of the Group select box are 
		// 
		// rel = "get-agents"
		// data-populate-agent-select = [AGENT SELECT BOX ID]
		// data-agent-list-url = [URL LISTING AGENT OPTIONS]
		// 
		$("#helpdesk_ticket_group_id")
		    .on("change", function(e){
		    	var _agent_ui = $("#helpdesk_ticket_responder_id")
		    	console.log("TEST");
		    	if(!_agent_ui.get(0)) return

		      	_agent_ui.html("<option value=''>...</option>")
			    $.post({ 	
	    			url: '/helpdesk/commons/group_agents/'+ this.value,
	        		success:  function(data){
						_agent_ui.html(data);
					}
				});
		    });
	})

}(window.jQuery);