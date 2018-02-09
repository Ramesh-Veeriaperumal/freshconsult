/*jslint browser: true, devel: true */
/*global  App */

window.App = window.App || {};
window.App.Tickets = window.App.Tickets || {};
(function ($) {
	"use strict";
	
	 App.Tickets.Compose = {
    current_module: '',

    onVisit: function (data) {
      invokeRedactor('helpdesk_ticket_ticket_body_attributes_description_html', 'ticket');
      $('#helpdesk_ticket_status').trigger("change");
      $(document).on('ready', function() {
        $.validator.messages.requester = I18n.t('validation.valid_contact');
      });

      // NOTE - Moved all inline scripts in compose_email.html.erb to compose_email.js
      ComposeEmail.init();
    },
		onLeave: function (data) {
      $('body').off('.compose');
      ComposeEmail.unbindEvents();
      $.validator.messages.requester = window.App.Tickets.Compose.original_requester_error_message;
		}
	};
}(jQuery));



