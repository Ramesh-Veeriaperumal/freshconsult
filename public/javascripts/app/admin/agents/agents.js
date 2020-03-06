/*jslint browser: true, devel: true */
/*global  App:true */
window.App = window.App || {};
window.App.Channel = window.App.Channel || new MessageChannel();

(function ($) {
	"use strict";
	
	App.Agents = {
		currentModule: '',
		onFirstVisit: function (data) {
			this.onVisit(data);
		},
		onVisit: function (data) {
			this.initializeSubModules();
			this.bindHandlers();
			if(this.currentModule !== ''){
				this[this.currentModule].onVisit();
			}
		},
		initializeSubModules: function() {
			switch(App.namespace){
				case "agents/show":
				this.currentModule = 'Show';
				break;
				case "agents/index":
				this.currentModule = 'Index';
				break;
			}
		},
		onLeave: function() {
			var $doc = $(document);
			$doc.off(".agentskills");
			$doc.off(".agent-roles");
			$(document).off('.agentEvents');
			this.currentModule = '';
		},
		bindHandlers: function () {
			this.startWatchRoutes();
			this.bindEmberRoutesClickActions();
		},
		startWatchRoutes: function () {
			var isIframe = (window !== window.top);
			if (isIframe) {
				// Transfer data through the channel
				window.App.Channel.port1.postMessage({ action: "update_iframe_url", path: '/admin' + location.pathname });
			}
		},
		bindEmberRoutesClickActions :  function () {
			$('.agent-ember-routes-btn').on("click", function(event){
				var dataAttributes = $(this).data();
				invokeEmberIframeMessage(event,{action: 'transition_to_route', pageRoute: dataAttributes.route, dynamicSegments: dataAttributes.dynamicSegments, queryParams: dataAttributes.queryParams});
			})
		}
	};
}(window.jQuery));
