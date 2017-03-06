/*jslint browser: true */
/*global  App */

window.App = window.App || {};
window.App.Admin = window.App.Admin || {};
(function ($) {
	"use strict";

	App.Admin.dkimConfigurations = {
		onVisit: function () {
			this.bindHandlers();
			this.copyToClipboard();
		},
		bindHandlers: function () {
			$(document).on('click.dkim', '.verify-dkim, .config-dkim', function (e) {
				$(this).text($(this).data('altText'));
				$(this).attr('disabled', 'disabled');
				
				var methodType = 'POST';
				if($(this).hasClass('verify-dkim')) {
					$(this).addClass('btn-verified');
					methodType = 'GET';
				}
				
				var self = this;
				$.ajax({
					dataType: 'script',
					method: methodType,
					url: $(self).data('url'),
					success: function (response) {}
				})
			})

			$(document).on('click.dkim', '.list-toggle', function (e) {
				e.preventDefault();
				if(!$(this).hasClass('disable')) {
					$(this).parents('.dkim-list ').toggleClass('active');
					$(this).siblings('.verification-status').toggleClass('hide');
				}
			})

			$(document).on('focus.dkim', '.clip-data', function () {
				$('.copy-clip').removeClass('show');
				$(this).select();
				$(this).siblings('.copy-clip').addClass('show');
			})

			$(document).on('mouseleave.dkim', '.copy-clip', function () {
				if($(this).data('copied')) {
					$(this).removeClass('show');
					$(this).attr('data-original-title', "Copy to Clipboard");
					$(this).data('copied',false);
				}
			})
		},
		copyToClipboard: function () {
			var clipboard = new Clipboard('.copy-clip', {
			    target: function(trigger) {
			        return $(trigger).siblings("input.clip-data")[0];
			    }
			});

			clipboard.on('success', function(e) {
				console.log(e.trigger)
				$(e.trigger).attr('data-original-title', "Copied");
				$(e.trigger).data('copied',true)
				$(e.trigger).twipsy('show');
			    e.clearSelection();
			});
		},
		unbindHandlers: function () {
			$(document).off('.dkim');
		},
		onLeave: function () {
			this.unbindHandlers();
		}
	};

}(window.jQuery));
