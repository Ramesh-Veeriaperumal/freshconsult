/*jslint browser: true, devel: true */
/*global App, highlight_code  */

window.App = window.App || {};
window.App.Discussions = window.App.Discussions || {};

(function ($) {
	"use strict";

	window.App.Discussions.Topic = {
		onVisit: function () {
			this.lookForHash();
			this.bindHandlers();
			this.cleanInlineCSS();
			App.Discussions.Monitorship.init();
		},

		onLeave: function () {
			this.unbindHandlers();
			App.Discussions.Monitorship.unbind();
		},

		cleanInlineCSS: function () {
			$('.post-content *').css('position', '');
		},

		lookForHash: function () {
			var hash = window.location.hash;
			if ($(hash).length === 1) {
				$.scrollTo(hash);
			} else if (hash === '#reply-to-post') {
				this.openReplyForm();
			}
		},

		bindHandlers: function () {
			this.bindChangeStamp();
			this.bindPostEditLink();
			this.bindPostEditCancelLink();
			this.bindPostUpdateForm();
			this.bindReplyLink();
			this.bindReplyCancelLink();
			this.addTargetTopForLinks();
			App.Discussions.Moderation.bindShowMore();
			highlight_code();
		},

		bindReplyLink: function () {
			var $this = this;
			$('body').on('click.topic_show', '[rel=topic-reply]', function (ev) {
				ev.preventDefault();
				$this.openReplyForm();
			});
		},

		bindReplyCancelLink: function () {
			var $this = this;
			$('body').on('click.topic_show', '[rel=topic-reply-cancel]', function (ev) {
				ev.preventDefault();
				$this.closeReplyForm();
			});
		},

		openReplyForm: function () {
			var $this = this;
			$('#new-reply').addClass('replying');
			$('.topic-reply').bringToView();
			$this.invokeReplyEditor();
		},

		invokeReplyEditor: function() {
			$('#sticky_redactor_toolbar').removeClass('hide');
      invokeEditor('reply_description', 'forum');
    },

		closeReplyForm: function () {
			$('#new-reply').removeClass('replying');
		},

		bindChangeStamp: function () {
			$('body').on('click.topic_show', '[id^=stamp_change]', function (ev) {
				var url = $('#stamp_type').data('url');
				$('#stamp-data').html('');
				$('#stamp-data').addClass('sloading loading-small');

				App.track('Topic Stamp Change');
				$.ajax({
					url : url,
					data: { stamp_type: $(this).data('value') },
					type: 'PUT'
				});
			});
		},

		bindPostEditLink: function () {
			var $this = this;
			$('body').on('click.topic_show', "[rel=post-edit]", function (ev) {
				ev.preventDefault();
				var conv = $this.findPostElement(this);
				conv.find('.post-content').hide();
				conv.find('.attachment_wrapper.post-attachment.multifile').hide();
				conv.find('.post-edit').trigger('afterShow').show();
				setTimeout(function () {
					$this.invokeReplyEditor();
				}, 1000);
      });
		},

		bindPostEditCancelLink: function () {
			var $this = this;
			$('body').on('click.topic_show', "[rel=post-edit-cancel]", function (ev) {
				ev.preventDefault();
				var conv = $this.findPostElement(this);
				conv.find('.post-content').show();
				conv.find('.attachment_wrapper.post-attachment.multifile').show();
				conv.find('.post-edit').hide();
			});
		},

		bindPostUpdateForm: function () {
			var $this = this;
			$('body').on('submit.topic_show', '[rel=post-update]', function (ev) {
				if ($(this).valid()) {
					$this.blockElement($this.findPostElement(this));
				}
			});
		},

		unbindHandlers: function () {
			$('body').off('.topic_show');
			App.Discussions.Moderation.unbindShowMore();
		},

		blockElement: function (element) {
			$(element).block({
				message: " <h1>...</h1> ",
				css: {
					display: 'none',
					backgroundColor: '#FFFFFF',
					border: 'none',
					color: '#FFFFFF',
					opacity: 0
				},
				overlayCSS: {
					backgroundColor: '#FFFFFF',
					opacity: 0.6
				}
			});
		},

    addTargetTopForLinks: function () {
			$('.reload-page a').each(function() {
				var hrefArray = this.href.split('/').slice(-1)[0];
				if(hrefArray.indexOf('#') == -1) {
					$(this).attr('target', '_top');
				}
			});
    },

		unblockElement: function (element) {
			$(element).unblock();
		},

		findPostElement: function (element) {
			return $(element).parents('.conversation');
		}
	};

}(window.jQuery));
