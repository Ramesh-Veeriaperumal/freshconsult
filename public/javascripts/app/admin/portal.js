/*jslint browser: true */
/*global  App, setPostParam, confirm */

window.App = window.App || {};
window.App.Admin = window.App.Admin || {};
(function ($) {
	"use strict";

	App.Admin.Portal = {
		onVisit: function () {
			this.bindHandlers();
		},
		
		bindHandlers: function () {
			this.bindFormHide();
			this.portalUrlChange();
			this.bindFormChange();
			this.bindImageUpload();
			this.bindDeleteConfirmCancel();
			this.handleSaveFailure();
		},

		bindFormHide: function () {
			$("#enable-portal").on("change.portal", function () {
				$('.hidden-items').toggle($("#enable-portal:checked").length !== 0);
				$('#errorExplanation').toggle($("#enable-portal:checked").length !== 0);
				if ($("#enable-portal:checked").length === 0) {
					$('[rel=confirmdelete]').trigger('click');
				}
			}).trigger("change");
		},

		portalUrlChange: function () {
			$("#PortalUrl").on('blur.portal', function () {
				var input_url = $('#PortalUrl').val(),
					protocol_exists = !(input_url.indexOf('http://') && input_url.indexOf('https://')),
					get_index = input_url.indexOf("://"),
					result_url = input_url.substring(get_index + 3);
				if (protocol_exists) {
					$('#PortalUrl').val(result_url);
				}
			});
		},

		bindFormChange: function () {
			$("[data-rebrand-form]").on("change.portal", function (ev) {
				$(this).data('formChanged', true);
			});
		},

		bindImageUpload: function () {
			$('.fileAdminUpload').on("change.portal", function () {
				setPostParam(this.form, "redirect_url", window.location);
				$(this.form).submit();
			});
		},

		bindSaveAndCustomize: function (confirm_text) {
			$("[rel=customize-portal]").on("click.portal", function (ev) {
				ev.preventDefault();
				var form = $(this).parents('form:first');
				if (form.valid()) {
					if (form.data('formChanged')) {
						ev.preventDefault();
						if (confirm(confirm_text)) {
							setPostParam(form, "customize_portal", true);
							form.submit();
						}
					} else {
						window.location = $(this).attr('href');
					}
				}
			});
		},

		bindDeleteConfirmCancel: function () {
			$('body').on('click.portal', '#disable-portal-cancel, #disable-portal .close', function () {
				$("#enable-portal").trigger('click');
			});
		},

		handleSaveFailure: function () {
			if (App.namespace === "admin/portal/create") {
				$("#enable-portal").trigger('click');
			}
		},

		unbindHandlers: function () {
			$('body').off('.portal');
		},

		onLeave: function () {
			this.unbindHandlers();
		}
	};
}(window.jQuery));
