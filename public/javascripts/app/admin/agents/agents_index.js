/*jslint browser: true, devel: true */
/*global  App:true */
window.App = window.App || {};
window.App.Agents = window.App.Agents || {};


(function($) {
  'use strict';

  App.Agents.Index = {
	onFirstVisit: function(data) {
		this.onVisit(data);
	},

	onVisit: function(data) {
		this.bindHandlers();
	},

    	bindHandlers: function() {
		var $doc = $(document);
		$doc.ready(function(){
			if($("#agentTab li.active .agent-list-count").data("agentCount") < 20){
				$(".sort_list").hide();
			}

		    var agents_search_autocomplete_index_path = $('.agents-search').attr('autocomplete-path');
		    $('.agents-search').select2({
		    	minimumInputLength: 2,
		    	multiple: true,
		    	ajax: {
		        	url: agents_search_autocomplete_index_path,
		        	quietMillis: 1000,
		        	data: function (term) {
		            		return { q: term };
		        	},
		        	results: function (data) {
		            		return { results: data.results };
		        	}
		      	},
		      	formatResult: function(result) {
			    	var email = result.email;
			    	if(email.trim() != "")
			    		email = "  (" + email + ")";
			    	return "<b>"+ result.value + "</b><br><span class='falcon-select2-override select2_list_detail'>" + email + "</span>";
			    },
		      	formatSelection: function(result) {
			    	window.location.href = "/users/" + result.id;
			    },
			    formatSelectionCssClass: function(result) {
			    	return "hide";
			    }
		    });
		});

		$doc.on('click.agentEvents', ".delete_agent_btn", function(){
			$("#agent-filters").data('agent', $(this).data('agent'));
		});

		$doc.on("click.agentEvents", '#agent-deletion-confirmation-submit', function(){
			var agent_id = $("#agent-filters").data('agent');
			$('#agent_convert_id_'+agent_id).trigger('click');
			$("#agent-filters").data('agent', null);
		});
	}
  };

}(window.jQuery));
