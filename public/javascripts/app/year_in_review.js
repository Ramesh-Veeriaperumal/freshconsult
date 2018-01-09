/*jslint browser: true, devel: true */
/*global  App */

window.App = window.App || {};
window.App.YearInReview  = window.App.YearInReview || {};

(function ($) {
	"use strict";
	
	App.YearInReview = {
		player: null,

		init: function() {
			var video = document.querySelector('#year-in-review-video');
			this.player = plyr.setup('#year-in-review-video');

			this.bindEvent();

			$(document).on('pjax:beforeSend.yearin_review', function (event, xhr, settings, options) {
        this.destroy();
      }.bind(this));

      $('body').on('hidden.yearin_review', '#year_in_video_model', function () {
      	this.player[0].stop();
      }.bind(this));
		},

		bindEvent: function() {
			$(document).on('click.yearin_review', '#year-in-video', this.watchVideo.bind(this));
			$(document).on('click.yearin_review', '#share-video', this.shareVideo.bind(this));
			$(document).on('click.yearin_review', '#close-btn', this.closeBanner.bind(this));
		},

		watchVideo: function() {
			var self = this;
			setTimeout(function() {
				self.player[0].play();
			}, 500);
		},

		shareVideo: function() {
			var self = $('#share-video');
			self.prop('disabled', 'disabled');
			$('#share-btn-text').text(self.data('sharing'));

			$.ajax({
				type: "POST",
				dataType: 'json',
				url:"/yearin_review/share",
				success: function(response) {
					setTimeout(function() {
						$('#share-icon').removeClass('ficon-share').addClass('ficon-tick-new');
						$('#share-btn-text').text(self.data('shared'));
					}, 500);
				}
			});
		},

		closeBanner: function() {
			$.ajax({
				type: "POST",
				dataType: 'json',
				url:"/yearin_review/clear",
				success: function(response) {
					setTimeout(function() {
						$('.year-in-review').remove();
					}, 1000);
				}
			})
		},

		destroy: function() {
			$(document).off('.yearin_review');
			$('body').off('.yearin_review')
			this.player = null;
		}
	};

}(window.jQuery));