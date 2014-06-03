/*jslint browser: true, devel: true */
/*global  App, $H, delay */

window.App = window.App || {};
window.App.Discussions = window.App.Discussions || {};
(function ($) {
	"use strict";

	App.Discussions.Moderation = {
		banUser: function (user_id, fade_out_in) {
			fade_out_in = fade_out_in || 10;
			$('[data-user=' + user_id + ']').addClass('disabled');
			setTimeout(function () {
				$('[data-user=' + user_id + ']').fadeOut();
			}, fade_out_in * 1000);
		},
		banPostUser: function (post_id, fade_out_in) {
			var user_id = $('#post_' + post_id).addClass('inline-flash').data('user');
			fade_out_in = fade_out_in || 10;
			
			$('[data-user=' + user_id + ']').not('#post_' + post_id).addClass('disabled');
			setTimeout(function () {
				$('[data-user=' + user_id + ']').fadeOut();
			}, fade_out_in * 1000);
		},
		approvePost: function (post_id, fade_out_in) {
			$('#post_' + post_id).addClass('inline-flash');
			fade_out_in = fade_out_in || 10;
			setTimeout(function () {
				$('.comm-items #post_' + post_id).fadeOut();
			}, fade_out_in * 1000);
		}
	};
}(window.jQuery));
