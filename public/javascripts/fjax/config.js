/***
How to configure this:
Start with a forward slash
Once a path is matched, subsequent scanning will not be done.

For Eg:
If you want to load seperate assets for the following paths:
 - helpdesk
 - helpdesk/tickets
 - helpdesk/tickets/{id}
You can have it as follows:

"/helpdesk": 'helpdesk',
"/helpdesk/tickets": 'helpdesk-tickets',
"/helpdesk/tickets/": 'helpdesk-tickets-show'

You should have 3 JS Assets/files having the same names.
The Class names should be like:
 - App.Helpdesk
 - App.HelpdeskTickets
 - App.HelpdeskTicketsShow
***/

/*jslint browser: true */
/*global  Fjax, App */

window.App = window.App || {};
window.Fjax = window.Fjax || {};

(function ($) {
	"use strict";
	Fjax.Config = {
		paths: {
			"/discussions": 'discussions',
			"/admin": 'admin',
			"/freshfone/call_history": 'freshfonecallhistory',
			"/reports/freshfone/summary_reports": 'freshfonereports',
			"/contacts": 'contacts',
			"/users": 'contacts',
			"/companies": 'companies',
			"/helpdesk/tickets": 'tickets',
			"/search": 'search',
			"/helpdesk/agent_status": 'freshfoneagents'
		},
		LOADING_WAIT: 60
	};
}(window.jQuery));
