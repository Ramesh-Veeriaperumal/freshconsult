/*jslint browser: true, devel: true */
/*global  App, $H, delay, pjaxify */

window.App = window.App || {};
window.App.Discussions = window.App.Discussions || {};
(function ($) {
	"use strict";

	App.Discussions.TopicList = {

		filterTimer: 0,

		onVisit: function () {
			this.bindHandlers();
			this.bindForBulkActions();
		},

		bindHandlers: function () {
			this.bindChangeFilterLink();
			this.bindFilterOnChange();
			this.bindSortChange();
			this.bindHoverTip();
			this.bindFilterOutsideClick();
		},

		bindHoverTip: function () {
			$('.latest_reply').each(function () {
				var tipUrl = $(this).data('tipUrl');
				$(this).qtip({
					prerender: false,
					position: {
						my: 'top left',
						at: 'bottom left',
						viewport: $(window)
					},
					style: {
						classes: 'ui-tooltip-ticket ui-tooltip-rounded',
						tip: {
							mimic: 'center'
						}
					},
					content: {
						text: '...',
						ajax: {
							url: tipUrl,
							once: true
						}
					}
				});
			});
		},

		bindSortChange: function () {
			var $this = this;
			$('body').on('click.discussions.topic_list', 'a[rel=topic-sort-item]', function (ev) {
				ev.preventDefault();
				$(this).parent().siblings(".active").removeClass("active");
				$(this).parent().addClass("active");
				$this.refreshTopics();
			});
		},

		bindChangeFilterLink: function () {
			$('#filtered_by').data('changed', false);
			$('body').on('click.discussions.topic_list', '.item-filter-stamps', function (ev) {
				var filterInput = $('.item-filter input'),
					container = $('#filtered_by').select2('container');

				if (!$(ev.target).parents().is('.filter-stamps') && !$(ev.target).parents().is(container)) {
					$('#filter-link').hide();
					$('.filter-stamps').removeClass('hide');
					$('#filtered_by').select2('focus');
					$('#filtered_by').select2('open');
					container.find('input').trigger('click');
				}
			});
		},

		bindFilterOnChange: function () {
			var $this = this;
			$('body').on('change.discussions.topic_list', '#filtered_by', function () {
				$(this).data('changed', true);
				$(this).val();
				clearTimeout($this.filterTimer);
				$this.filterTimer = setTimeout(function () {
					$this.filterTransition();
					$this.refreshTopics();
				}, 4000);
			});
		},

		bindFilterOutsideClick: function () {
			var $this = this;
			$('body').on('click.discussions.topic_list', function (ev) {
				if (!$(ev.target).parents().is('.item-filter-stamps') && !$(ev.target).is('.item-filter-stamps')) {
					clearTimeout($this.filterTimer);
					$this.filterTransition();
					if ($('#filtered_by').data('changed')) {
						$this.refreshTopics();
					}
				}
			});
		},

		filterTransition: function () {
			$('.filter-stamps').addClass('hide');
			$('#filter-link').text(this.filterElements());
			$('#filter-link').show();
			$('#filtered_by').select2('close');
		},

		filterElements: function () {
			var selectedFilters = [],
				choices_selected = $('#filtered_by').select2('container').find(".select2-search-choice");

			if (choices_selected.length !== 0) {
				choices_selected.each(function () {
					selectedFilters.push(' ' + $.trim($(this).text()));
				});
			} else {
				selectedFilters.push('All');
			}
			return selectedFilters;
		},

		refreshTopics: function () {
			var url = window.location.pathname + '?order=' + this.orderValue(),
				stamp_values = $('#filtered_by').val();
			if (stamp_values) {
				url = url + '&filter=' + stamp_values;
			}
			App.track('Filtered Topics', {stamps_used: stamp_values, order: this.ordervalue});
			pjaxify(url);
		},

		orderValue: function () {
			return $("#topic-sort-menu li.active > a").data('value');
		},

		bindForBulkActions: function () {
			$('#topic-bulk-action :checkbox').prop('disabled', $(".comm-items :checkbox").length === 0);
			$("#topic-bulk-form").append($("<input type='hidden' name='_method'/>"));

			this.bindBulkCheckAll();
			this.bindBulkCheckboxChange();
			this.bindBulkSubmit();
		},

		bindBulkCheckAll: function () {
			$('body').on('click.discussions.topic_list', '#topic-select-all', function () {
				$(".comm-items :checkbox")
					.prop("checked", $(this).prop("checked"))
					.trigger('change');
			});
		},

		bindBulkCheckboxChange: function () {
			$('body').on('change.discussions.topic_list', ".comm-items :checkbox", function () {
				$('#topic-bulk-action :checkbox').prop('checked', $(".comm-items :checkbox:checked").length === $(".comm-items :checkbox").length);

				var toggleFilters = $('#topic-bulk-form :checkbox:checked').length > 0;
				$('#topic-bulk-action-btn').toggle(toggleFilters);
				$('#lf-item-sort').toggle(!toggleFilters);
				$('#lf-item-filter').toggle(!toggleFilters);
			});

		},

		bindBulkSubmit: function () {
			$('body').on('click.discussions.topic_list', '#topic-bulk-action-btn .btn', function () {
				if (confirm($(this).data('confirm'))) {
					var $this = $(this),
						form = $("#topic-bulk-form");
					form.find('input[name=_method]').attr('value', $this.data('method'));
					form.attr('action', $this.data('actionUrl'));
					form.submit();
				}
			});
		},

		onLeave: function () {
			clearTimeout(this.filterTimer);
			$('body').off('.discussions.topic_list');
		}
	};
}(window.jQuery));
