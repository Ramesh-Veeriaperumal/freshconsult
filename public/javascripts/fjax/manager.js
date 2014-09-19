/*jslint browser: true, regexp: true, indent: 2, devel: true */
/*global  Fjax, App */

window.App = window.App || {};
window.Fjax = window.Fjax || {};

(function ($) {
	"use strict";
	Fjax.Manager = {
		current: '', //Current Namespace being in use
		previous: '',
		visited: [],

		start: function () {
			this.bindPjaxListeners();
			this.loadReqdAssets();
			$(document).one('ready', function () {
				Fjax.Manager.loadedPage();
			});
		},

		loadReqdAssets: function (path) {
			path = path || window.location.pathname;
			var asset = this.assetForPath(path), $this = this;
			this.previous = this.current;
			if (!asset) {
				this.current = '';
				return;
			}
			
			this.current = asset;
			Fjax.Assets.serve(asset);
		},

		className: function (asset) {
			return asset.camelize().capitalize();
		},

		assetForPath: function (given_path) {
			var path;
			for (path in Fjax.Config.paths) {
				if (Fjax.Config.paths.hasOwnProperty(path) && given_path.startsWith(path)) {
					console.log("About to load", Fjax.Config.paths[path]);
					return Fjax.Config.paths[path];
				}
			}
			return false;
		},

		bindPjaxListeners: function () {
			var $this = this;
			$(document).bind('pjax:beforeSend', function (event, xhr, settings, options) {
				$this.loadReqdAssets(options.url.replace(/^.*\/\/[^\/]+/, ''));
			});
			$(document).bind('pjax:beforeReplace', function () {
				$this.leavePage();
			});

			$(document).bind('pjax:end', function () {
				$this.loadedPage();
			});
		},

		loadedPage: function () {
			var $this = this, waitingForAsset, waitingCount;
			if (this.current === '') {
				return;
			}


			if (this.loadedCurrent()) {
				$('body').trigger('assetLoaded.fjax');
				if (this.alreadyVisited(this.current)) {
					this.onVisit();
				} else {
					this.onFirstVisit();
				}
			} else {
				waitingForAsset = setInterval(function () {

					this.count = this.count || 1;
					if ($this.loadedCurrent()) {
						clearInterval(waitingForAsset);
						$('body').trigger('assetLoaded.fjax');
						$this.onFirstVisit();
					} else {
						if (this.count > Fjax.Config.LOADING_WAIT * 10) {
							clearInterval(waitingForAsset);
							console.log('Error trying to load ', this.current);
							$this.current = '';
						}
					}
					this.count += 1;

				}, 100);
			}

			this.visited.push(this.current);

			this.previous = '';
		},

		leavePage: function () {
			if (this.previous === '') {
				return;
			}

			this.onLeave();
		},

		loadedCurrent: function () {
			if (this.current === '') {
				return true;
			}

			return Fjax.Assets.alreadyLoaded(this.current);
		},

		alreadyVisited: function (namespace) {
			return (this.visited.indexOf(namespace) > -1);
		},

		onFirstVisit: function () {
			App[this.className(this.current)].onFirstVisit();
		},

		onVisit: function () {
			App[this.className(this.current)].onVisit();
		},

		onLeave: function () {
			App[this.className(this.previous)].onLeave();
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
