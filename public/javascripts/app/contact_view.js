/*global  App */

window.App = window.App || {};
window.App.Contacts.Contact_show = window.App.Contacts.Contact_show || {};

(function ($) {
	"use strict";

	window.App.Contacts.Contact_show = {
		prevBgInfo: '',
		tagList: '',
		onFirstVisit: function (data) {
			this.onVisit(data);
		},
		onVisit: function(data) {
			App.Contacts.Contacts_merge.initialize();
			this.checkForInfoMsgs();
			this.bindEvents();
		},
		switchToForm: function(showForm) {
			if($('.form-save').length > 0 && showForm) {
				$('.form-save').slideDown();
				$('#tag-list').slideUp();
				$('.tags-wrapper').slideDown();
				$('.sp_paragraph').addClass('editarea');
				this.prevBgInfo = $('.sp_paragraph').val();
				this.tagList = $('#user_tag_names').select2('val');
			} else {
				$('#tag-list').slideDown();
				$('.tags-wrapper').slideUp();
				$('.sp_paragraph').removeClass('editarea').height(0);
				$('.form-save').slideUp(400, function() {
					$('.sp_paragraph')
						.height($('.sp_paragraph')[0].scrollHeight)
				});
			}
		},
		flashUpdatedDiv: function() {
			$('#updateForm').addClass('record_highlight');  
			setTimeout(function(){ 
				$('#updateForm').removeClass('record_highlight');  
			},1000);
		},
		addNewTag: function() {
			this.switchToForm(true);
			$('.tags-wrapper').find('.select2-search-field input').focus();
		},
		cancelSave: function(e) {
			$('#updateForm').find('.ajax-error').text('');
			this.switchToForm(false);
			$('.sp_paragraph').val(this.prevBgInfo);
			$('#user_tag_names').select2('val', this.tagList);
		},
		toggleUsername: function() {
			var	scrollTop = $(this).scrollTop(),
				userName = $('.contact-info-fields').find('.user-info .lead'),
				stickyHeader = $('#contactHeaderSticky');
				
			if(scrollTop > userName.offset().top + userName.height() - stickyHeader.outerHeight()) {
				$('.sticky-header-wrapper').find('.contact-name').css('visibility', 'visible');
			}
			else {
				$('.sticky-header-wrapper').find('.contact-name').css('visibility', 'hidden');
			}
		},
		populateTags: function(tags) {
			var tagsHtml = "<div class='tag_list'>",
				savedTags = [],
				option = tags.length > 0 ? 'edit' : 'add';
			$.each(tags, function(idx, item) {
				tagsHtml += "<a class='btn btn-flat' href='/contacts?tag=" + item.id + "' > " + escapeHtml(item.name) + " </a>";
				savedTags.push(escapeHtml(item.name));
			});
			tagsHtml += "<a class='btn btn-flat add-new-tag' href='#'>"
							+ "<span class='ficon-plus'></span>"
							+ tagsOptions[option]
							+ "</a>";
			$('#tag-list').html(tagsHtml);
			$('#user_tag_names').select2('val', savedTags);
			this.tagList = $.extend({}, savedTags);
		},
		checkForInfoMsgs: function() {
			if ($.trim( $('div.info-highlight').text() ).length != 0) {
				$('div.info-highlight').show();
			}
		},
		switchConversationView: function(element) {
			$('.conv-menu .sub-info').text(element.text());
		},
		bindEvents: function() {
			var self = this;
			$('body').on('click.contact-view', '.add-new-tag', function(e){
				e.preventDefault();
				self.addNewTag();
			});
			$('body').on('click.contact-view', '.sp_paragraph', function(e) {
				self.switchToForm(true);
			});
			$('body').on('click.contact-view', '.cancel-form', function(e) {
				e.preventDefault();
				self.cancelSave();
			});
			$('body').on('submit.contact-view', '.edit_user', function(e) {
				e.preventDefault();
				self.makeAjaxCall();
			});
			$('body').on('click.contact-view', '.dropdown-menu .item', function(e) {
				e.preventDefault();
				self.switchConversationView($(this));
			});
			$('body').on('click.contact-view', '#customer-delete-confirmation-submit', function(e) {
				e.preventDefault();
				$('#delete_customer').trigger('click');
			});
			$(window).on('scroll.contact-view', this.toggleUsername);
			$('.sp_paragraph')
					.height($('.sp_paragraph')[0].scrollHeight);
		},
		makeAjaxCall: function() {
			var data = $('.edit_user').serializeArray(),
				self = this;
	
			$.ajax({
				type: "PUT",
				url: "/contacts/" + $('#userid').val() + "/update_description_and_tags",
				data: data,
				dataType: "json",
				success: function(result, status, xhr){
					self.ajaxSuccess(result);
				},
				beforeSend: function() {
					self.ajaxBefore();
				},
				error: function(xhr, status, error){
					self.ajaxFailure(JSON.parse(xhr.responseText));
				},
				complete: function() {
					self.ajaxComplete();
				}
			});
		},
		ajaxSuccess: function(resp) {
			$('#updateForm').find('.ajax-error').text('');
			this.populateTags(resp);
			this.switchToForm(false);
			this.flashUpdatedDiv();
			$('.tags-wrapper').find('.select2-search-field input').blur();
			$('.sp_paragraph')
					.blur();
		},
		ajaxFailure: function(errors) {
			var errorText;
			$.each(errors, function(index, item) {
				errorText = item[1] + '<br/>';
			});
			$('#updateForm').find('.ajax-error').html(errorText);
		},
		ajaxComplete: function() {
			$('#user_tag_names').select2('enable');
			$('.sp_paragraph').removeClass('disabled');
			$('.save-form').removeClass('disabled');
		},
		ajaxBefore: function() {
			$('#user_tag_names').select2('disable');
			$('.sp_paragraph').addClass('disabled');
			$('.save-form').addClass('disabled');
		},
		onLeave: function() {
			$('body').off('.contact-view');
			$(window).off('.contact-view');
		}
	};
}(window.jQuery));