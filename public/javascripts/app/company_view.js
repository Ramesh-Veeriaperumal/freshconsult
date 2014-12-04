/*global  App */

window.App = window.App || {};
window.App.Companies.Company_show = window.App.Companies.Company_show || {};

(function ($) {
	"use strict";

	window.App.Companies.Company_show = {
		prevBgInfo: '',
		onFirstVisit: function (data) {
			this.onVisit(data);
		},
		onVisit: function(data) {
			this.bindEvents();
			this.adjustWidthForNoContacts();
		},
		switchToForm: function(showForm) {
			if($('.form-save').length > 0 && showForm) {
				$('.form-save').slideDown();
				$('.sp_paragraph').addClass('editarea');
				this.prevBgInfo = $('.sp_paragraph').val();
			} else {
				$('.form-save').slideUp();
				$('.sp_paragraph').removeClass('editarea');
			}
		},
		flashUpdatedDiv: function() {
			$('#updateForm').addClass('record_highlight');  
			setTimeout(function(){ 
				$('#updateForm').removeClass('record_highlight');  
			},1000);
		},
		cancelSave: function(e) {
			$('#updateForm').find('.ajax-error').text('');
			this.switchToForm(false);
			$('.sp_paragraph').val(this.prevBgInfo);
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
		adjustWidthForNoContacts: function() {
			var parentWidth = $('.no-contacts').outerWidth(),
				childWidth = $('.no-contacts-msg').outerWidth(true);

			$('.border-wrap').width( (parentWidth-childWidth)/2);
		},
		bindEvents: function() {
			var self = this;
			$('body').on('click.company-view', '.sp_paragraph', function(e) {
				self.switchToForm(true);
			});
			$('body').on('click.company-view', '.cancel-form', function(e) {
				e.preventDefault();
				self.cancelSave();
			});
			$('body').on('click.company-view', '.save-form', function(e) {
				e.preventDefault();
				self.makeAjaxCall();
			});
			$(window).on('scroll.company-view', this.toggleUsername);
			$('.sp_paragraph')
					.height($('.sp_paragraph')[0].scrollHeight);
		},
		makeAjaxCall: function() {
			var data = $('.edit_user').serializeArray(),
				self = this;
				data._method = 'PUT';
	
			$.ajax({
				type: "POST",
				url: "/companies/update/" + $('#companyid').val(),
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
			this.switchToForm(false);
			this.flashUpdatedDiv();
			$('.sp_paragraph')
					.height($('.sp_paragraph')[0].scrollHeight)
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
			$('.sp_paragraph').removeClass('disabled');
			$('.save-form').removeClass('disabled');
		},
		ajaxBefore: function() {
			$('.sp_paragraph').addClass('disabled');
			$('.save-form').addClass('disabled');
		},
		onLeave: function() {
			$('body').off('.company-view');
			$(window).off('.company-view');
		}
	};
}(window.jQuery));