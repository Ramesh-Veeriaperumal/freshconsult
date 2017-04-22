/*jslint browser: true, devel: true */
/*global  App:true */
window.App = window.App || {};


(function ($) {
	"use strict";

	App.Agents = {
    	currentModule: '',
		onFirstVisit: function (data) {
			this.onVisit(data);
		},
		onVisit: function (data) {
			this.initializeSubModules();
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
		}
	};
}(window.jQuery));
