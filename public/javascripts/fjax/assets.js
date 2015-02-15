/*jslint browser: true, devel: true */
/*global Topic:true, Fjax */
(function ($) {
	"use strict";
	Fjax.Assets = {
		loaded: [],
		javascripts: [],
		stylesheets: [],
		currently_loading: [],
		
		setup: function (javascripts, stylesheets, cloudfront_version, host_url) {
			this.javascripts = javascripts;
			this.stylesheets = stylesheets;
			this.cloudFrontVersion = cloudfront_version;
			this.host_url = host_url;
			
			if (this.isDevEnv()) {
				this.cleanupPaths('javascripts');
				this.cleanupPaths('stylesheets');
			}
		},
		
		isDevEnv: function () {
			return (this.cloudFrontVersion === 'development');
		},
		
		cleanupPaths: function (type) {
			var name, i, length, hasJST = false;
			for (name in this[type]) {
				if (this[type].hasOwnProperty(name)) {
					length = this[type][name].length;
					hasJST = false;
					for (i = 0; i < length; i += 1) {
						this[type][name][i] = this[type][name][i].replace('public/', '/');
						
						if (type === 'javascripts' && this[type][name][i].endsWith('.jst')) {
							hasJST = true;
							this[type][name][i] = null;
						}
					}
					
					// For Rails 3, dont Merge the below code 
					// or any Fjax Asset related code from this commit 
					if (hasJST) {
						this[type][name].push('/packages/' + name + '.jst');
						this[type][name] = this[type][name].compact();
					}
				}
			}
			
		},
		
		isJSNeeded: function (asset) {
//			return (this.javascripts.indexOf(asset) > -1);
			return (typeof (this.javascripts[asset]) !== 'undefined');
		},
		
		isCSSNeeded: function (asset) {
//			return (this.stylesheets.indexOf(asset) > -1);
			return (typeof (this.stylesheets[asset]) !== 'undefined');
		},
		
		isLoading: function (asset) {
			return (this.currently_loading.indexOf(asset) > -1);
		},
		
		alreadyLoaded: function (asset) {
			return (this.loaded.indexOf(asset) > -1);
		},
		
		assetList: function (asset, type) {
			type = (type === 'js' || type === 'css') ? type : 'js';
			if (this.isDevEnv()) {
				if (type === 'css') {
					return this.stylesheets[asset];
				} else {
					//JS
					return this.javascripts[asset];
				}
			} else {
				return [window.cloudfront_host_url + '/' + asset + '.' + type];
			}
		},
		
		serve: function (asset, callback) {
			callback = callback || function () {};
			
			if (!this.isJSNeeded(asset) && !this.isCSSNeeded(asset)) {
				return false;
			}
			
			if (this.alreadyLoaded(asset)) {
				callback();
				return true;
			}
			
			if (this.isLoading(asset)) {
				return true;
			}
			
			if (this.isJSNeeded(asset)) {
				this.currently_loading[asset] = true;
				var $this = this;
				this.load_js(this.assetList(asset, 'js'), function () {
					callback();
					$this.loaded.push(asset);
				});
			}
			
			if (this.isCSSNeeded(asset)) {
				this.load_css(this.assetList(asset, 'css'));
			}
		},
		
		load_js: function (urls, callback) {
			urls = typeof (urls) === "string" ? [urls] : urls;
			var current_url = urls[0], $this = this;
			urls = urls.slice(1, urls.length);
			
			if (urls.length) {
				
				this.ajax_load_script(current_url, function () {
					$this.load_js(urls, callback);
				});
			} else {
				this.ajax_load_script(current_url, function () {
					callback();
				});
			}
			
		},
		
		load_css: function (urls) {
			urls = typeof (urls) === "string" ? [urls] : urls;
			$.each(urls, function (i, url) {
				$("<link/>", {
					rel: "stylesheet",
					type: "text/css",
					href: url
				}).appendTo("head");
			});
			
		},
		
		ajax_load_script: function (url, callback) {
			callback = callback || function () {};
			var script = document.createElement("script");
			script.type = "text/javascript";

			if (script.readyState) {  //IE
				script.onreadystatechange = function () {
					if (script.readyState === "loaded" ||
								script.readyState === "complete") {
						script.onreadystatechange = null;
						callback();
					}
				};
			} else {  //Others
				script.onload = function () {
					callback();
				};
			}

			script.src = url;
			document.getElementsByTagName("head")[0].appendChild(script);
		}
	};
	
}(window.jQuery));
/**
Scope Docs

Load and serve the assets necessary for this page.
Load assets only if they are not already loaded.

After the scripts are loaded for the first time, call the initialize method.
When the scripts required for the page are already loaded, call the onload method.

For the both the functions send the Controller and the Action
Every time the page is unloaded, call the unload Method

**/