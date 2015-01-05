/*jslint browser: true, devel: true */
/*global  App */

window.App = window.App || {};
(function ($) {
	"use strict";

	App.Discussions = {
		current_module: '',

		onFirstVisit: function (data) {
			this.onVisit(data);
		},
		onVisit: function (data) {
			this.Sidebar.start();
			this.Sidebar.hide();
			this.setSubModule();
			this.bindHandlers();
			$('.pagination a').attr('data-pjax', '#body-container');

			if (this.current_module !== '') {
				this[this.current_module].onVisit();
			}
		},

		setSubModule: function () {
			switch (App.namespace) {

			case 'discussions/moderation/index':
			case 'discussions/unpublished/index':
				this.current_module = 'Moderation';
				break;
			case 'discussions/topics/show':
				this.current_module = 'Topic';
				break;

			case 'discussions/forums/show':
				this.current_module = 'TopicList';
				break;

			case 'discussions/show':
			case 'discussions/categories':
				this.current_module = 'Category';
				break;

			}
		},

		bindHandlers: function () {

		},

		bindShortcuts: function () {
			$('.comm-items')
				.menuSelector('destroy')
				.menuSelector({
					activeClass: 'item-selected',
					onHoverActive: false,
					scrollInDocument: true,
					menuTrigger: $('.comm-item-title a')
				});
		},
		
		setSpamCounts: function (counts) {
			if (typeof (counts.waiting) !== 'undefined') {
				if (parseInt(counts.waiting, 10) > 0) {
					$('[rel=count-waiting]').text(" (" + parseInt(counts.waiting, 10) + ") ");
				} else {
					$('[rel=count-waiting]').empty();
				}
			}

			if (typeof (counts.unpublished) !== 'undefined') {
				if (parseInt(counts.unpublished, 10) > 0) {
					$('[rel=count-waiting]').text(" (" + parseInt(counts.unpublished, 10) + ") ");
				} else {
					$('[rel=count-waiting]').empty();
				}
			}
			
			if (typeof (counts.spam) !== 'undefined') {
				if (parseInt(counts.spam, 10) > 0) {
					$('[rel=count-spam]').text(" (" + parseInt(counts.spam, 10) + ") ");
				} else {
					$('[rel=count-spam]').empty();
				}
			}
		},

		onLeave: function (data) {
			this.Sidebar.leave();
			if (this.current_module !== '') {
				this[this.current_module].onLeave();
				this.current_module = '';
			}

		}
	};
}(window.jQuery));
