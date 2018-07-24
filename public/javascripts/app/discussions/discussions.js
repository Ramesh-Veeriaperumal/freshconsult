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
			this.recalcSticky();
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

			case 'discussions/topics/new':
			case 'discussions/topics/edit':
				this.current_module = 'NewTopic';
				break;
			}
		},

		bindHandlers: function () {
			this.bindDeleteConfirm();
		},

		recalcSticky: function (ele) {
			var elements = ['#sticky_header', '#cm-discussion-wrapper'];
			
			$(document).on("scroll.discussions.sticky.recalc", function () {
				elements.forEach(function(element) {
					if($(element).length) { 
						var top = $(element).css('top');
						if (top !== 'auto' && top !== '0px')
						{
							var sticky = $(element).data('sticky');
							 sticky.recalc();
						}
					}
				});
			});
		},

		bindDeleteConfirm: function () {
			if($('#del') !== undefined){
				var submit_btn_id = $('#del').data('target') + '-submit';
				$(submit_btn_id).on('click', function () {				
					$('#delete_object').trigger('click');
				})
			}
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
			$(document).off('.discussions.sticky.recalc');
			if (this.current_module !== '') {
				this[this.current_module].onLeave();
				this.current_module = '';
			}

		}
	};
}(window.jQuery));
