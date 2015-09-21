/*jslint browser: true, devel: true */
/*global Fjax, $LAB */
(function ($) {
	"use strict";
	Fjax.Assets = {
		loaded: {
			app: [],
			plugins: [],
			integrations: []
		},
		javascripts: {},
		stylesheets: {},
		
		setup: function (javascripts, stylesheets, host_url) {
			this.javascripts = javascripts;
			this.stylesheets = stylesheets;
			this.host_url = host_url;
		},
		
		isJSNeeded: function (asset, type) {
			type = type || 'app';
			return (typeof (this.javascripts[type][asset]) !== 'undefined');
		},
		
		isCSSNeeded: function (asset, type) {
			type = type || 'app';
			return (typeof (this.stylesheets[type][asset]) !== 'undefined');
		},
		
		alreadyLoaded: function (asset, type) {
			type = type || 'app';
			return (this.loaded[type].indexOf(asset) > -1);
		},
		
		serve: function (asset, callback) {
			callback = callback || function () {};
			
			if (!this.isJSNeeded(asset) && !this.isCSSNeeded(asset)) {
				return false;
			}
			
			if (this.isJSNeeded(asset)) {
				var $this = this;
				$LAB.script(this.javascripts.app[asset]).wait(function () {
					callback();
					$this.loaded.app.push(asset);
				});
			}
			
			if (this.isCSSNeeded(asset)) {
				this.load_css(asset);
			}
		},
		
		load_css: function (urls) {
			urls = typeof (urls) === "string" ? [urls] : urls;
			var $this = this;
			$.each(urls, function (i, url) {
				$("<link/>", {
					rel: "stylesheet",
					type: "text/css",
					href: $this.host_url + '/assets/' + url
				}).appendTo("head");
			});
			
		},
		
		plugin: function (name) {
			var $this = this;
			if (!this.alreadyLoaded(name, 'plugins')) {
				$LAB.script(this.javascripts.plugins[name]).wait(function () {
					$this.loaded.plugins.push(name);
					if (typeof (Fjax.Callbacks[name]) === 'function') {						
						Fjax.Callbacks[name]();
					}
				});
				
				if (this.isCSSNeeded(name, 'plugins')) {
					this.load_css(this.stylesheets.plugins[name]);
				}
			}
		},
		
		integration: function (name, callback) {
			var $this = this;
			if (typeof (callback) !== 'function') {
				callback = function(){};
			}
			
			if (!this.alreadyLoaded(name, 'integrations')) {
				$LAB.script(this.javascripts.integrations[name]).wait(function () {
					$this.loaded.integrations.push(name);
					callback();
				});
			}
			else {
				callback();
			}
		}

	};
	
}(window.jQuery));
/**
Scope Docs

Load and serve the assets necessary for this page.
Load assets only if they are not already loaded.

After the scripts are loaded for the first time, call the initialize method.
When the scripts required for the page are already loaded, call the onVisit/onFirstVisit method.

For the both the functions send the Controller and the Action
Every time the page is unloaded, call the onLeave Method

**/