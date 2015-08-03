/*jslint browser: true */
/*global  App */

window.App = window.App || {};
window.App.Admin = window.App.Admin || {};
(function ($) {
	"use strict";

	App.Admin.PortalSettings = {
		onVisit: function () {
			this.bindHandlers();
		},
		
		bindHandlers: function () {
			this.bindMultiRadio();
			this.bindShowCaptcha();
			this.bindForumCaptcha();
		},

		bindMultiRadio: function () {
			var $this = this;
			$(".multiple_radio input").on('change.portal_settings', function () {
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
			$('[name="account[features][anonymous_tickets]"]').on('change.portal_settings', function () {
				if ($('[name="account[features][anonymous_tickets]"]:checked').val() === "1") {
					$('.captcha').slideDown();
				} else {
					$('.captcha').slideUp();
				}
			}).trigger('change');
		},

		bindForumCaptcha: function () {
			$('.forums_visibility input[data-name]').on('change.portal_settings', function () {
				if ($('[data-name="account[features][hide_portal_forums]"]').is(':checked')) {
					$('#forum_captcha_section').slideUp();
				} else {
					$('#forum_captcha_section').slideDown();
				}
			}).trigger('change');
		},

		unbindHandlers: function () {
			$('body').off('.portal_settings');
		},

		onLeave: function () {
			this.unbindHandlers();
		}
	};
}(window.jQuery));
