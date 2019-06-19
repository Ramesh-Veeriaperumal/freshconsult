/*jslint browser: true */
/*global  App */

window.App = window.App || {};
window.App.Channel = window.App.Channel || new MessageChannel();

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
          this.current_module = 'Skills';
          break;
      case 'admin/user_skills/index':
          this.current_module = 'AgentSkills';
          break;
			case 'admin/dkim_configurations/index':
					this.current_module = 'dkimConfigurations';
					break;
      default:
          // Need to handle for other namespaces
          break;
			}
		},

		bindHandlers: function () {
			this.startWatchRoutes();
		},

		startWatchRoutes: function () {
			var isIframe = (window !== window.top);
			if (isIframe) {
        // Transfer data through the channel
        window.App.Channel.port1.postMessage({ action: "update_iframe_url", path: location.pathname });
			}
    },

		onLeave: function (data) {
			if (this.current_module !== '') {
				this[this.current_module].onLeave();
				this.current_module = '';
			}
		}
	};
}(window.jQuery));
