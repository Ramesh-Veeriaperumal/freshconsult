/*
 * jQuery popupbox (auto position inline popupbox)
 * @copyright Freshdesk
 * @version 1
 */

 // Refactor code into a proper plugin
(function ($) {

	"use strict";
	var Popupbox = function (element, settings) {
		this.realWorldName = "Popupbox";
		this.settings = settings;
		this.container = $(element);
		this.init();
		if (this.settings.keyboard) { this.bindEscapeKey(); }
		this.bindClick();
		return this;
	};

	Popupbox.prototype = {
		init: function () {

			this.content_container = this.container.find('.popupbox-content');
			this.external_container = $('[rel="' + this.container.attr('class') + '"]');
			this.active_container = this.external_container.length ? this.external_container :
																																	this.content_container;
			this.tab_elements = this.container.find('.popupbox-tabs > li');
			this.all_tab_links = this.container.find('.popupbox-tabs > li a:not(.persist)');
			this.tab_links = this.container.find('.popupbox-tabs > li a:not([href="#no_popup"])');
		},

		toggleTarget : function (element, toggle) {
			this.$element = $(element);
			if (!this.$element.length) { return; }
			var targetId = this.$element.attr('href');

			if (targetId == "#no_popup") {
				this.$element.toggleClass('active');
				// this.active_container.hide();
				return;
			}
			this.currentTarget = this.active_container.find(targetId);

			this.tab_links.removeClass('active');

			this.active_container.find('> div:not(' + targetId + ')').removeClass('active').hide();

			(toggle && this.currentTarget.is(':visible')) ? this.hideTarget() : this.showTarget();
		},
// Show target content and container
		showTarget: function () {
			this.currentTarget.show();
			this.active_container.show();
			this.alignShownTarget();
			this.addShownClass();
		},
// Align target content
		alignShownTarget: function () {
			var left = this.$element.offset().left,
				new_positon = left - this.currentTarget.width() + 35;
			// TODO add bottom 20px too
			if(new_positon <= 0){
				return;
			}
			left = new_positon;
			this.currentTarget.parents('div.popupbox-content').offset({ left: left});
		},
// Add active class and trigger shown on element
		addShownClass: function () {
			this.currentTarget.addClass('active');

			this.$element.addClass('active');
			this.$element.trigger('shown');
		},
// Hide the target content and container
		hideTarget: function () {
			this.currentTarget.hide();
			this.active_container.hide();

			this.removeShownClass();
		},
		removeShownClass: function () {
			this.currentTarget.removeClass('active');

			this.$element.removeClass('active');
			this.$element.trigger('hidden');
		},

// Custom Options
		hidePopupContents : function (elements) {
			this.active_container.hide().find('> div').hide();
			this.all_tab_links.removeClass('active');
			this.tab_elements.trigger('hidden');
		},

		hideVisibleContents : function (elements) {
			this.active_container.hide().find('> div').hide();
			this.tab_links.removeClass('active');
			this.tab_elements.trigger('hidden');
		},

		isAnyContentOpen: function () {
			return this.active_container.find('> div:visible').length > 0;
		},

		isClickInsidePlugin: function ($element) {
			return (!$element.parents('.popupbox-content, .popupbox-tabs').length);
		},

		bindEscapeKey: function () {
			var self = this;

			$(document).keyup(function (ev) {
				if (ev.which == 27 && self.isAnyContentOpen()) {
					ev.preventDefault();
					self.hideVisibleContents();
				}
			});
		},

		bindClick: function () {
			var self = this;

			$(document).bind('click', function (ev) {
				var $element = $(ev.target);
				if (self.isAnyContentOpen() && self.isClickInsidePlugin($element)) {
					self.hideVisibleContents();
				}
			});
		},

		show: function ($element) {
			var	container = $element.parents('.popupbox-tabs').parent(),
				popupbox = container.data('popupbox');
			if (popupbox !== undefined) {
				popupbox.toggleTarget($element, false);
			}
		}
	};

	$.fn.popupbox = function (options) {

		var settings = $.extend({
			keyboard: true
		}, options),
			popupbox;

		return this.each(function () {
			var $this = $(this);
			if ($this.data('popupbox') === undefined) {
				popupbox = new Popupbox(this, settings);
				$this.data('popupbox', popupbox);
			} else {
				popupbox = $this.data('popupbox');
			}

			if (typeof options === "string") {
				if (popupbox[options] === undefined) { return false; }
				popupbox[options]($this);
				return true;
			}

			$this.find('a[data-toggle="popupbox"]').bind('click', function (ev) {
				ev.preventDefault();

				popupbox.toggleTarget(this, true);
			});

			$(document).ready(function () {
				popupbox
					.toggleTarget(popupbox.content_container
						.find('.popupbox-tabs li.active:first a'), false);
			});

		});
	};

}(jQuery));
