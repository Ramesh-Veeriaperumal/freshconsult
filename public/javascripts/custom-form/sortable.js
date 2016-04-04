!(function ($) {
	var SmoothSort = function (element, options) {
		this.originalList	= element;
		this.options			= $.extend({}, $.fn.smoothSort.defaults, options, $(element).data());
		// this.options.placeholder = 'ui-state-highlight';
		this.extendOptions();
		this.init();
	};

	SmoothSort.prototype = {
		extendOptions: function () {
			var self		= this,
				copyHelper	= null,
				customStart	= this.options.start;

			this.options.start = function (e, ui) {
				if (typeof customStart == "function") {
					customStart(e, ui);
				}
				$('.ui-sortable').addClass('sort-started');
			};

			var customOver = this.options.over;
			this.options.over = function (e, ui) {
				if (typeof customOver == "function") {
					customOver(e, ui);
				}
				var currentParent = $(e.target).closest('ul');
			};

			var customHelper = this.options.helper;
			this.options.helper = function (e, ui) {
				if (typeof customHelper == "function") {
					customHelper(e, ui);
				}
				copyHelper = ui.clone().insertAfter(ui);
				$(copyHelper).addClass("draggingfield");// it will overwrite the hover effects for fields
				return ui.clone().data('parent', $(this));
				
			};

			var customStop = this.options.stop;
			this.options.stop = function (e, ui) {
				if (typeof customStop == "function") {
					customStop(e, ui);
				}
				ui.item.addClass('ticket-field-highlight');
				copyHelper && copyHelper.remove();
				$('.ui-sortable').removeClass('sort-started');
				setTimeout(function () { ui.item.removeClass('ticket-field-highlight'); }, 3000);
			};
		},

		init: function () {
			$(this.originalList).bind('sortstart', function (event, ui) {
				var ele_text = ui.item.data('drag-info');
				if (ele_text == null || ele_text == '') {
					ele_text = "Move here";
				}
				$('.ui-sortable-placeholder').append('<div class="ui-dragging-text">' + ele_text + '</div>');
			});
			$(this.originalList).sortable(this.options);
		},
		destroy: function () {
			$(document).off('click.custom-fields');
			$(document).off('change.custom-fields');
		}
	};

	$.fn.smoothSort = function (option) {
		return this.each(function () {
			var $this	= $(this),
				data	= $this.data("smoothSort"),
				options	= typeof option == "object" && option;
			if (!data && !$this.hasClass('ui-sortable')) {
				$this.data("smoothSort", (data = new SmoothSort(this, options)));
			}
		});
	};
})(window.jQuery);
