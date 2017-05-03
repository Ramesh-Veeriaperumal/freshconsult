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
