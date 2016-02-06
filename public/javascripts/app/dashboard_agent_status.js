/*jslint browser: true, devel: true */
/*global  App:true */

window.App = window.App || {};
(function ($) {
	"use strict";

	App.DashboardAgentStatus = {
		bindToggle: function () {
			var self=this;
			$('.filter_item').itoggle({
				checkedLabel: 'On',
				uncheckedLabel: 'Off'
			}).change(function() {

				var items = [];
				var $el = $(this);
				$el.prop('disabled','disabled');
				$.ajax({
					type: "POST",
					dataType: "json",
					url: $el.data('url'),
					data: {
						'value' : !$el.data('availability'),
						'id': $el.data('id')
					},
					success: function () {
						var row=$("#agent_status_"+$el.data('id')).clone(true);

						if($("#agent_status_"+$el.data('id')).data("id")=="available"){

							$("#agent_status_"+$el.data('id')).remove();
							row.prependTo($('#not-accepting-table'));
						    $("#agent_status_"+$el.data('id')).data("id","unavailable");


						}
						else{

							$("#agent_status_"+$el.data('id')).remove();
							row.prependTo($('#accepting-table'));
							$("#agent_status_"+$el.data('id')).data("id","available");

						}
							self.resetToggleButton($el.data('id'));
							self.checkAgentsList();
							self.updateAgentCount();

							$("#agent_status_" + $el.data('id') + ' .filter_item').data('availablity', !$el.data('availability'));
							$("#agent_status_" + $el.data('id') + ' .active_since')
								.html($('#agents-list').data('textSince'))
								.animateHighlight();


					}
				});
			});

		},

		resetToggleButton : function(agent_id){
			$("#agent_status_"+agent_id).find('.toggle-button').remove();
			$("#agent_available_"+agent_id).data("itoggle", false);
			$("#agent_available_"+agent_id).removeAttr('disabled');
			$("#agent_available_"+agent_id).itoggle();
		},
		checkAgentListLength : function(table_id,title_id){
			var table = table_id+" tr";
			if($(table).length==0){
				$(title_id).show();
			}
			if($(table).length>0){
				$(title_id).hide();
			}

		},
		updateAgentList : function(){
			    this.updateAgentCount();
				$('ul.ticket-minimal-swap li').removeClass('current');
				$('.ticket-minimal-tab').removeClass('current');
				$('.ticket-minimal').addClass('current');
				$('#ticket-tab-1').addClass('current');
				this.checkAgentsList();
		},
		updateAgentCount : function(){
			$("#tickets_accepting_count").html($('#accepting-table tr').length);
			$("#tickets_not_accepting_count").html($('#not-accepting-table tr').length);
		},
		checkAgentsList : function(){
			this.checkAgentListLength("#accepting-table","#ticket-accepting");
			this.checkAgentListLength("#not-accepting-table","#ticket-not-accepting");
			$(" #ticket-available").hide();
			$(" #ticket-unavailable").hide();
		}

	};
}(window.jQuery));
