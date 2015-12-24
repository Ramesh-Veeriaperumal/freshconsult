(function ($) {
	"use strict";
	function isNonBlankString(string) {
		return (string != undefined && !string.blank());
	}
	var messageTypes = {
		RECORDING : 0,
		UPLOADED_AUDIO : 1,
		TRANSCRIPT : 2
	}, MessageSelector,
	AUDIO_FILE_FORMAT = 'mp3',
	currentNumberId = freshfone.currentNumberId;
	MessageSelector = function (element, options) {
		var self = this, defaults;
		this.$container = $(element);
		
		defaults = {
			attachmentName: "",
			recordingUrl: "",
			attachmentUrl: "",
			attachmentId: "",
			attachementDeleteCallback: function () {},
			attachementDeleteCallbackContext: this
		};

		this.options = $.extend({}, defaults, options);
		this.options.canShowAttachedFile = isNonBlankString(this.options.attachmentName);
		this.options.canShowRecordedFile = isNonBlankString(this.options.recordingUrl);

		this.init();

	};
	
	MessageSelector.prototype = {
		init: function () {
			this.$messageType = this.$container.find('[rel=messageType]');
			this.$allMessageTypesSelectors = this.$container.find('[rel^=message_]');
			this.$messageTypeInput = this.$container.find('[rel=message_type_input]');
			
			this.$messageFile = this.$container.find('.message-file');
			this.$messageRecording = this.$container.find('.message-recording');
			
			this.$attachment = this.$container.find('[rel=attachment]');
			this.$attachmentFile = this.$container.find('.attached_file');
			this.$attachmentPlaybackLink = this.$container.find('.attached_file a');
			this.$attachmentFileName = this.$attachmentFile.find('.attached_file_name');
            this.$attachmentFileLink = this.$attachmentFile.find('.attached_file_link');
			this.$attachmentFileInput = this.$container.find('input[type=file]');
			this.$attachmentInput = this.$container.find('[rel=attachment_id]');
			this.$attachmentRemoveLink = this.$container.find('.remove_attachment');
			this.$attachmentCancelLink = this.$container.find('.cancel_attachment');

			this.$clientRecordContainer = this.$messageRecording.find('.client-record-container');
			this.$clientRecord = this.$messageRecording.find('.client-record');
			this.$recordedMessage = this.$messageRecording.find('.recorded-message');
			this.$recordingInput = this.$messageRecording.find('input');
			this.$recordingPlaybackLink = this.$messageRecording.find('.recorded_file_link a');
			this.$recordingRemoveLink = this.$container.find('.remove_recording');
			this.$recordingCancelLink = this.$container.find('.cancel_recording');
			
			this.showAttachedFile();
			this.showRecordingFile();
			this.chooseMessageType();
			this.bindMessageTypeChange();
			this.bindAttachment();
			this.bindAttachmentDelete();
			this.bindRecording();
			this.bindRecordingDelete();
			this.bindRecordingCancel();
			this.bindAttachmentCancel();
		},
		chooseMessageType: function () {
			var message_type = this.$container.find('[rel=message_type_input]:first').data('messageType'),
				self = this;
			if (message_type === "") { message_type = messageTypes.TRANSCRIPT; }
			this.$messageType.removeClass('current');
			this.$messageType.each(function () {
				if ($(this).data('value') === message_type) {
					self.changeActiveMsg(this);
					$(this).addClass('current');
				}
			});
		},
		bindMessageTypeChange: function () {
			var self = this;
			this.$messageType.click(function (ev) {
				self.$messageType.removeClass('current');
				self.changeActiveMsg(this);
				$(this).addClass('current');
			});
		},
		changeActiveMsg: function (element) {
			this.msgtype = $(element).data('value');
			this.$allMessageTypesSelectors.hide();
			this.$container.find('[rel=message_' + this.msgtype + ']').show();
			if (this.msgtype === messageTypes['TRANSCRIPT'] && !this.textareaResized) {
				var textarea = this.$container.find('.message-input:visible');
				if (!textarea.data('autosize')) { textarea.autosize(); }
				this.textareaResized = true;
			}
			this.updateMessageType();
		},
		updateMessageType: function () {
			this.$messageTypeInput.val(this.msgtype);
		},
		bindAttachment: function () {
			var self = this;

			this.$attachmentFileInput.change(function () {
				self.$attachmentFileLink.hide();
				this.fileName="<i class='attach-file-done'></i>"+self.getFileName()
				self.$attachmentFileName.html(this.fileName);
				self.$attachmentRemoveLink.show();
				self.$attachmentFile.show();

				self.$attachment.hide();
			});
		},
		getFileName: function () {
			var filename = this.$attachmentFileInput.val(),
				lastIndex = filename.lastIndexOf("\\");
			if (lastIndex >= 0) {
				filename = filename.substring(lastIndex + 1);
			}
			return filename;
		},
		bindAttachmentDelete: function () {
			
			var self = this;
			
			this.$attachmentRemoveLink.click(function () {
				var id = self.$attachmentInput.val();
				self.stopAudioPlayback(self.$attachmentPlaybackLink);
				self.$attachmentPlaybackLink.attr('href', '');
			
				threeSixtyPlayer.init();
				self.$attachmentFileInput.val('');
				self.$attachmentFile.hide();
				self.$attachment.show();
				if (self.options.canShowAttachedFile) {
					self.$attachmentCancelLink.show();
				}
				
				self.deleteAudio(id);
				$(this).hide();
			});
		},
		bindAttachmentCancel: function () {
			if (!this.options.canShowAttachedFile) { return false; }
			var self = this;
			this.$attachmentCancelLink.click(function () {
				self.$attachmentPlaybackLink.attr('href', self.options.attachmentUrl);
                self.$attachmentFileLink.show();
				self.$attachmentFileName.html(self.options.attachmentName);
				self.$attachmentFile.show();
				self.$attachment.hide();
				self.$attachmentRemoveLink.show();
				$(this).hide();
			});
		},
		stopAudioPlayback: function (link) {
			var href = link.attr('href');
			if (threeSixtyPlayer.getSoundByURL(href)) {
				threeSixtyPlayer.getSoundByURL(href).stop();
			}
		},
		deleteAudio: function (id) {
			this.options.attachementDeleteCallback
				.apply(this.options.attachementDeleteCallbackContext, [id]);
		},
		bindRecording: function () {
			var self = this;
			this.$clientRecord.click(function (ev) {
				ev.preventDefault();
				var $record_button = $(this);
				if ($record_button.hasClass('active-record')) {
					self.setPrepearingState();
					if (freshfonecalls.tConn) { freshfonecalls.tConn.sendDigits('#'); }
				} else {
					freshfonecalls.recordMessage(self, currentNumberId);
				}
			});
		},
		setRecordingState: function () {
			this.$clientRecord
				.addClass('stop-recording active-record')
				.removeClass('mute')
				.button('recording');
		},
		setPrepearingState: function () {
			this.$clientRecord
				.addClass('mute')
				.removeClass('stop-recording')
				.button('preparing');
		},
		resetRecordingState: function () {
			this.$clientRecord
				.removeClass('stop-recording mute active-record')
				.button('reset');
		},
		updateRecording: function (data) {
			var url = (data || {}).url;
			url = escapeHtml(url);
			this.$clientRecord
				.removeClass('active-record mute stop-recording')
				.button('reset');
			if (url && url != "") {
				this.$clientRecordContainer
					.hide();
				this.$recordingPlaybackLink
					.attr('href', url + '.' + AUDIO_FILE_FORMAT);
				this.$recordingInput
					.val(url);
				this.$recordedMessage
					.removeClass('sloading loading-small')
					.show();
				this.$recordingRemoveLink.show();
			}
		},
		fetchRecordedUrl: function () {
			var self = this;
			$.ajax({
				url: '/freshfone/device/recorded_greeting',
				dataType: 'json',
				method: 'GET',
				data: {'type' : 'wait'},
				success: function (data) {
					self.updateRecording(data);
					threeSixtyPlayer.init();
				}
			});
		},
		bindRecordingDelete: function () {
			var self = this;

			this.$recordingRemoveLink.click(function () {

				self.stopAudioPlayback(self.$recordingPlaybackLink);
				self.$recordingInput.val('');
				threeSixtyPlayer.init();
				if (self.options.canShowRecordedFile) {
					self.$recordingCancelLink.show();
				}

				self.$recordedMessage.hide();
				self.$clientRecordContainer.show();
				$(this).hide();
			});
		},
		bindRecordingCancel: function () {
			if (!this.options.canShowRecordedFile) { return false; }
			var self = this;
			this.$recordingCancelLink.click(function () {
				self.$recordingInput.val(self.options.recordingUrl);
				self.$recordedMessage.show();
				self.$clientRecordContainer.hide();
				self.$recordingRemoveLink.show();
				$(this).hide();
			});
		},
		showAttachedFile: function () {

			if (this.options.canShowAttachedFile) {
				this.$attachment.hide();
				this.$attachmentFile.show();
				this.$attachmentCancelLink.hide();
			} else {
				this.$attachmentCancelLink.remove();
				this.$attachmentRemoveLink.hide();
			}
		},
		showRecordingFile: function () {
			if (this.options.canShowRecordedFile) {
				this.$clientRecordContainer.hide();
				this.$recordedMessage.show();
				this.$recordingCancelLink.hide();
			} else {
				this.$recordingCancelLink.remove();
				this.$recordingRemoveLink.hide();
			}
		}
	};
	
	$.fn.messageSelector = function (options) {
		return this.each(function () {
			var $this = $(this),
				data = $this.data('messageSelector');
			if (!data) {
				$this.data('messageSelector', (data = new MessageSelector(this, options)));
			}
		});
	};
}(jQuery));