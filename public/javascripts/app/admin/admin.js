/*jslint browser: true */
/*global  App */

window.App = window.App || {};
(function ($) {
	"use strict";

	App.Admin = {
		current_module: '',

		onFirstVisit: function (data) {
			this.onVisit(data);
		},
		onVisit: function (data) {
			this.setSubModule();
			this.bindHandlers();
			if (this.current_module !== '') {
				this[this.current_module].onVisit();
			}
		},

		setSubModule: function () {
			switch (App.namespace) {
			case 'admin/portal/index':
			case 'admin/portal/edit':
			case 'admin/portal/enable':
			case 'admin/portal/create':
			case 'admin/portal/update':
				this.current_module = 'Portal';
				break;

			case 'admin/portal/settings':
				this.current_module = 'PortalSettings';
				break;

			case 'accounts/manage_languages':
			case "accounts/update_languages":
				this.current_module = 'LanguageSettings';
				break

			case 'admin/chat_widgets/index':
			case 'admin/chat_widgets/edit':
				this.current_module = 'LiveChatAdminSettings';
				break;
			case 'admin/email_notifications/index':
				this.current_module = 'AdminFontSettings'
				  break;
      case 'admin/skills/index':
      case 'admin/skills/new':
      case 'admin/skills/edit':
          this.current_module = 'Skills';
          break;
      case 'admin/user_skills/index':
          this.current_module = 'AgentSkills';
          break;
      default:
          // Need to handle for other namespaces
          break;
			}
		},

		bindHandlers: function () {

		},

		onLeave: function (data) {
			if (this.current_module !== '') {
				this[this.current_module].onLeave();
				this.current_module = '';
			}
		}
	};
}(window.jQuery));
