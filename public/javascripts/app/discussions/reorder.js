/*jslint browser: true, devel: true */
/*global  App, $H, delay */

window.App = window.App || {};
window.App.Discussions = window.App.Discussions || {};
(function ($) {
	"use strict";

	App.Discussions.Reorder = {
		start: function () {
			this.toggleReorderButton();
			this.bindReorderButton();
			this.bindSortable();
			this.bindFormSubmit();
			this.bindButtonSubmit();
			this.bindCancelReorder();
		},

		toggleReorderButton: function () {
			if ($('.comm-items ul li:not(.no_order)').length < 2) {
				$('#categories_reorder_btn').hide();
			}
		},

		bindReorderButton: function () {
			var $this = this;
			$('body').on("click.discussions.reorder", "#categories_reorder_btn", function (ev) {
				ev.preventDefault();
				$this.classToggle();
				$('.comm-items li.no_order').hide();
			});
		},

		classToggle: function () {
			$('#sticky_header').toggleClass('sort-active');
			$('#forum_category_sort').toggleClass('sort-active');
		},

		bindSortable: function () {
			$('.comm-items ul').data('list_item', $('.comm-items ul').html());
			$('.comm-items ul').sortable({
				containment: 'parent',
				tolerance: 'pointer',
				item: 'li:not(.disabled)',
				handle: '.handle-reorder'
			});
		},

		bindFormSubmit: function () {
			var $this = this;
			$('body').on("submit.discussions.reorder", ".form-reorder", function (ev) {
				this.reorderlist.value = $this.positionHash();
			});
		},

		bindButtonSubmit: function () {
			var $this = this;
			$('body').on("click.discussions.reorder", "#categories_submit_btn", function (ev) {
				ev.preventDefault();
				$.ajax({
					url: $('.comm-items ul').parents('form').attr('action'),
					type: 'PUT',
					dataType: 'script',
					data: { 
						reorderlist: $this.positionHash(),
						category_id: $('#reorder_category_id').val()
					},
					success: function () {
						App.Discussions.Sidebar.reload();
					}
				});
				var url = $this.submitUrl;
				$this.classToggle();
				$('.comm-items li.no_order').show();
			});
		},

		bindCancelReorder: function () {
			var $this = this;
			$('body').on("click.discussions.reorder", "#categories_cancel_btn", function (ev) {
				ev.preventDefault();
				$('.comm-items ul').html($('.comm-items ul').data('list_item'));
				$this.classToggle();
				$('.comm-items li.no_order').show();
			});
		},

		positionHash: function () {
			var positionHash = $H();
			$.each($('.comm-items li:not(.no_order)'), function (index, item) {
				positionHash.set(item.getAttribute('item_id'), index + 1);
			});
			return positionHash.toJSON();
		},

		leave: function () {
			this.submitUrl = '';
			$('body').off('.discussions.reorder');
			$('.comm-items ul').sortable("destroy");
		}
	};
}(window.jQuery));
