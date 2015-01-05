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
		},
		invalidPost: function (post_id, fade_out_in) {
			$('#post_' + post_id).hide();
			$('#post_' + post_id + ' .action-icon').removeClass('sloading loading-small');
			$('#post_' + post_id + ' .action-icon a').show();
			setTimeout(function () {
				$('.inline-flash').remove();
				$('#post_' + post_id).fadeIn();
			}, fade_out_in * 1000);
		},
		bindShowMore: function () {
			$('body').on('click.discussions.show_more', ".post-desc, .less-link, .more-link", function (ev) {
				ev.preventDefault();
				$(this).find('.more').toggle();
				$(this).find('.more-link').toggle();
			});
		},
		closeModal: function (type, close_in) {
			setTimeout(function () {
				if($('#' + type + ' .modal-body .comm-items .comm-item:visible').length === 0){
					$('#' + type).modal('hide');
				}
			}, close_in * 1000);
		},
		unbindShowMore: function () {
			$('body').off('.discussions.show_more');
		},
		onVisit: function () {
			this.bindShowMore();
		},
		onLeave: function () {
			this.unbindShowMore();
		}
	};
}(window.jQuery));
