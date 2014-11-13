/*jslint browser: true, devel: true */
/*global  App:true */

window.App = window.App || {};
(function ($) {
	"use strict";
	
	App.Dashboard = {
		init: function () {
			setTimeout(function() {
			  $('#quests-section-container, #mini-leaderboard, #Activity, #sales-manager-container').trigger('afterShow');
			},50);

			$('#sales-manager-container').on('remoteLoaded', function(e){
			  if($('#sales-manager-container').children().hasClass('details-container')){
			    $(this).slideDown();
			  }
			});
		},
		bindToggle: function () {
			$('.filter_item').itoggle({
				checkedLabel: 'On',
				uncheckedLabel: 'Off'
			}).change(function() {
				var $el = $(this);

				$.ajax({
					type: "POST",
					dataType: "json",
					url: $el.data('url'),
					data: {
						'value' : !$el.data('availability'),
						'id': $el.data('id')
					},
					success: function () {
						$("#agent_status_" + $el.data('id') + ' .filter_item').data('availablity', !$el.data('availability'));
						$("#agent_status_" + $el.data('id') + ' .active_since')
							.html($('#agents-list').data('textSince'))
							.animateHighlight();;

					}
				});
			});
		}
	};
}(window.jQuery));
