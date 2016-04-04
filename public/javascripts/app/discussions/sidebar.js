/*jslint browser: true, devel: true */
/*global  App */

window.App = window.App || {};
window.App.Discussions = window.App.Discussions || {};
(function ($) {
	"use strict";

	App.Discussions.Sidebar = {
		activeForum: null,
		categoriesLoaded: false,
		sidebarActive: false,
		
		start: function () {
			this.setupStaticSidebar();
			this.bindHandlers();
			this.setCurrentPage();
			this.sidebarActive = false;
			$('#cm-sb-list').trigger('afterShow');
		},

		setupStaticSidebar: function () {
			var $this = this;
			$this.setSidebarHeight($("#body-container").height() - 20);

			$(document).on("sticky_kit:stick.discussions.sidebar", "#cm-discussion-wrapper", function (ev) {
				$this.setSidebarHeight($(window).height() - 20);
			});

			$(document).on("sticky_kit:unstick.discussions.sidebar", "#cm-discussion-wrapper", function (ev) {
				$this.setSidebarHeight($("#body-container").height() - 20);
			});
		},

		setSidebarHeight: function (height) {
			$("#community-sidebar").height(height);
			$("#cm-sb-list").height(height - ($(".cm-sb-title").outerHeight(true) + 10));
		},

		setCurrentPage: function () {
			var forum_id, forum_ele, category_id;
			$('#community-sidebar li').removeClass('active');
			switch (App.namespace) {
			case 'discussions/index':
				$('#community-sidebar [data-page-name=all_posts]').parent().addClass('active');
				break;
			case 'discussions/categories':
				$('#community-sidebar [data-page-name=folders]').parent().addClass('active');
				break;
			case 'discussions/your_topics':
				$('#community-sidebar [data-page-name=your_posts]').parent().addClass('active');
				break;
			case 'discussions/moderation/index':
				if (window.location.pathname === '/discussions/moderation/filter/waiting') {
					$('#community-sidebar [data-page-name=waiting]').parent().addClass('active');
				} else {
					$('#community-sidebar [data-page-name=spam]').parent().addClass('active');
				}
				break;
			case 'discussions/unpublished/index':
				if (window.location.pathname === '/discussions/unpublished/filter/unpublished' ||
						window.location.pathname === '/discussions/moderation/filter/waiting') {
					$('#community-sidebar [data-page-name=waiting]').parent().addClass('active');
				} else {
					$('#community-sidebar [data-page-name=spam]').parent().addClass('active');
				}
				break;
			case 'discussions/show':
			case 'discussions/edit':
				category_id = parseInt(window.location.pathname.replace('/discussions/', ''), 10);
				$('#sb-discussions-category-' + category_id).parent().addClass('active toggle-open');
				break;
			case 'discussions/forums/show':
			case 'discussions/forums/edit':
				forum_id = parseInt(window.location.pathname.replace('/discussions/forums/', ''), 10);
				$('#sb-discussions-forum-' + forum_id).parent().addClass('active');
				break;
					
			default:
				if (this.activeForum !== null) {
					$('#sb-discussions-forum-' + this.activeForum).parent().addClass('active');
				}
				break;
			}
			
			$('#community-sidebar li.active').parents('.cm-sb-cat-item').addClass('toggle-open');
			if (!$('.cm-sb-cat-item').hasClass('toggle-open')) {
				$('.cm-sb-cat-item').first().addClass('toggle-open');
			}
			
		},

		setCurrentPageAs: function (page) {
			this.activeForum = null;
			$('#community-sidebar li').removeClass('active');
			$('#community-sidebar [data-page-name=' + page + ']').parent().addClass('active');
		},

		setActiveForumAs: function (forum_id) {
			this.activeForum = parseInt(forum_id, 10);
			$('#community-sidebar li').removeClass('active');
			$('#community-sidebar [data-forum-id=' + forum_id + ']').parent().addClass('active');
		},

		bindHandlers: function () {
			this.bindToggleButton();
			this.bindOutsideClick();
			this.bindExpandLink();
			this.bindItemClick();
			this.bindSidebarClose();
			this.bindSidebarLoaded();
		},
		
		bindSidebarLoaded: function () {
			var $this = this;
			$('#cm-sb-list').on('remoteLoaded', function () {
				$this.setCurrentPage();
				$this.categoriesLoaded = true;
			});
		},

		bindToggleButton: function () {
			var $this = this;
			$("body").on('click.discussions.sidebar', '#cm-sb-toggle', function () {
				$this.toggle();
			});
		},

		bindOutsideClick: function () {
			var $this = this;

			$(document).on('click.discussions.sidebar', function (ev) {
				var container = $('#community-sidebar'), sidebarToggle = $('#cm-sb-toggle');
				if (!container.is(ev.target) && container.has(ev.target).length === 0 && !sidebarToggle.is(ev.target)) {
					$this.hide();
				}
			});
		},

		bindExpandLink: function () {
			$(document).on('click.discussions.sidebar', '.forum_expand', function (ev) {
				ev.stopPropagation();
				$(this).parent().toggleClass("toggle-open");
			});
		},

		bindItemClick: function () {
			$(document).on('click.discussions.sidebar', '#community-sidebar a', function (ev) {
				$('#community-sidebar').find(".active").removeClass("active");
				$(this).parent().addClass('active');
			});
		},

		bindSidebarClose: function () {
			var $this = this;
			$(document).on('click.discussion.sidebar', '#cm-sb-close', function (ev) {
				$this.hide();
			});
		},
		
		show: function () {
			if (!this.categoriesLoaded) {
				$('#cm-sb-list').trigger('afterShow');
			}
			$("#community-sidebar").show();
			$('body').addClass('cs-show');
			this.sidebarActive = true;
		},

		hide: function () {
			var $this = this;
			$('body').removeClass('cs-show');
			setTimeout(function () {
				var canShow = $('body').hasClass('cs-always-show');
				if (!canShow) {
					$("#community-sidebar").hide();
					$this.sidebarActive = false;
				} else {
					$("#community-sidebar").show();
					$this.sidebarActive = true;
				}
			}, 300);
		},
		
		toggle: function () {
			if (this.sidebarActive) {
				this.hide();
			} else {
				this.show();
			}
		},
		
		reload: function () {
			$('#cm-sb-list').trigger('reload');
		},

		leave: function (data) {
			this.activeForumId = null;
			this.hide();
			$(document).off('.discussions.sidebar');
			$(window).off('.discussions.sidebar');
			$('body').off('.discussions.sidebar');
		}
	};
}(window.jQuery));