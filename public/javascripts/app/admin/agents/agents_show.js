/*jslint browser: true, devel: true */
/*global  App:true */
window.App = window.App || {};
window.App.Agents = window.App.Agents || {};


(function($) {
  'use strict';

  App.Agents.Show = {
	onFirstVisit: function(data) {
		this.onVisit(data);
	},

	onVisit: function(data) {
		this.bindHandlers();
	},

    	bindHandlers: function() {
		var $doc = $(document);
		$doc.on("click.agentEvents", "#reset_password_button", function() 
		{
			$(this).addClass("disabled");
		});

		$doc.on("click.agentEvents", '#cancel_agent_button', function()
		{
			$('#reset_password_template').modal('hide');
		}); 
		// need to convert this to util
		$doc.ready(function(){
		  if ($.trim( $('div.info-highlight').text() ).length != 0) {
		    $('div.info-highlight').show();
		  }

		  if ($.trim( $('div.action_buttons').text() ).length != 0) {
		    $('div.action_buttons').show();
		  }
		});

		$doc.on("click.agentEvents", '#agent-deletion-confirmation-submit', function(){
			$('#agent_contact_convert').trigger('click');
		});

		$doc.on('click.agentEvents', '#agent-gamification-reset-submit', function(){ 
			$('#agent_score_reset').trigger('click');
		});
	},
	onLeave: function(data) {
		$(document).off('.agentEvents');
	}
  };

}(window.jQuery));