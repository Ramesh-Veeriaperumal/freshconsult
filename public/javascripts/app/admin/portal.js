/*jslint browser: true */
/*global  App */

window.App = window.App || {};
window.App.Admin = window.App.Admin || {};
(function ($) {
	"use strict";

	App.Admin.Portal = {
		onVisit: function () {
			this.bindHandlers();
		},
		
		bindHandlers: function () {
			this.bindMultiRadio();
			this.bindShowCaptcha();
		},

		bindMultiRadio: function () {
			var $this = this;
			$(".multiple_radio input").on('change.portal', function () {
				var current_btn_group = $('#' + $(this).data('group'));
				$this.toggleValues(current_btn_group);
			});
		},

		toggleValues: function (current_btn_group) {
			$(current_btn_group).find('input[type=hidden]').each(function () {
				$(this).val($(current_btn_group).find('[data-name="' + $(this).attr('name') + '"]').is(':checked') ? 1 : 0);
			});
		},

		bindShowCaptcha: function () {
			$('[name="account[features][anonymous_tickets]"]').on('change.portal', function () {
				if ($('[name="account[features][anonymous_tickets]"]:checked').val() === "1") {
					$('.captcha').slideDown();
				} else {
					$('.captcha').slideUp();
				}
			}).trigger('change');
		},

		unbindHandlers: function () {
			$('body').off('.portal');
		},

		onLeave: function () {
			this.unbindHandlers();
		}
	};
}(window.jQuery));
