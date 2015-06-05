/*jslint browser: true, devel: true */
/*global  App, $H, delay */

window.App = window.App || {};
window.App.Solutions = window.App.Solutions || {};
(function ($) {
	"use strict";

	App.Solutions.Reorder = {
		start: function () {
			this.toggleReorderButton();
			this.bindReorderButton();
			this.bindFormSubmit();
			this.bindButtonSubmit();
			this.bindCancelReorder();
		},

		toggleReorderButton: function () {
			if ($('.comm-items ul li').length < 2) {
				$('#reorder_btn').hide();
			}
		},

		bindReorderButton: function () {
			var $this = this;
			$('body').on("click.solutions.reorder", "#reorder_btn", function (ev) {
				ev.preventDefault();
				$this.bindSortable();
				$this.classToggle();
				$this.hideSearchIcon();
			});
		},

		classToggle: function () {
			$('#sticky_header').toggleClass('sort-active');
			$('#solution_sort').toggleClass('sort-active');
		},

		bindSortable: function () {
			$('.comm-items ul').data('list_item', $('.comm-items ul').html());
			$('.comm-items ul').sortable({
				containment: 'parent',
				tolerance: 'pointer',
				item: 'li:not(.disabled)'
			});
		},

		bindFormSubmit: function () {
			var $this = this;
			$('body').on("submit.solutions.reorder", ".form-reorder", function (ev) {
				this.reorderlist.value = $this.positionHash();
			});
		},

		bindButtonSubmit: function () {
			var $this = this;
			$('body').on("click.solutions.reorder", "#submit_btn", function (ev) {
				ev.preventDefault();
				$.ajax({
					url: $('.comm-items ul').parents('form').attr('action'),
					type: 'PUT',
					dataType: 'script',
					data: {
						reorderlist: $this.positionHash(),
						category_id: $('#reorder_category_id').val(),
						folder_id: $('#reorder_folder_id').val()
					},
					success: function () {
						$('.comm-items ul').data('list_item', $('.comm-items ul').html());
						$this.showSearchIcon();
						// App.Discussions.Sidebar.reload();
						$('body').trigger('afterReorder');
					}
				});
				var url = $this.submitUrl;
				$('.comm-items ul').sortable("destroy");
				$this.classToggle();
			});
		},

		bindCancelReorder: function () {
			var $this = this;
			$('body').on("click.solutions.reorder", "#cancel_btn", function (ev) {
				ev.preventDefault();
				$('.comm-items ul').html($('.comm-items ul').data('list_item'));
				$('.comm-items ul').sortable("destroy");
				$this.classToggle();
				$this.showSearchIcon();
			});
		},

		positionHash: function () {
			var positionHash = $H();
			$.each($('.comm-items li'), function (index, item) {
				positionHash.set(item.getAttribute('item_id'), index + 1);
			});
			return positionHash.toJSON();
		},

		showSearchIcon: function () {
			$('#search-show').show();
		},

		hideSearchIcon: function () {
			$('#search-show').hide();
		},

		leave: function () {
			this.submitUrl = '';
			$('body').off('.solutions.reorder');
			$('.comm-items ul').sortable("destroy");
		}
	};
}(window.jQuery));
