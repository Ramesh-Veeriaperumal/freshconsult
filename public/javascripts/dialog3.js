// !PATTERN
"use strict"

var FRESHDIALOG = {}
FRESHDIALOG.nextid = 0;
FRESHDIALOG.template = '<div class="modal fade freshdialog">' + 
							'<div class="modal-header">' +
								'<button type="button" class="close" data-dismiss="modal" aria-hidden="true">&times;</button>' +
								'<h3></h3>'+
							'</div>' + 
							'<div class="modal-body loading-center"></div>' +
						'</div>';
FRESHDIALOG.id_keyword = "ui-freshdialog-";
FRESHDIALOG.defaults = {
	width: 500,
	title: '',
	classes: '',
	keyboard: true,
	backdrop: true,

	//The below options are for event callbacks. 
	show: false, 
	shown: false, 
	hide: false, 
	hidden: false 
}
FRESHDIALOG.options_to_fetch = ['width', 'title','classes','remote','keyboard','backdrop'];

(function($){

	$.closeDialog = function() {
		//Closing the active modal
		if ($('.modal.freshdialog.in').length > 0) {
			$('.modal.freshdialog.in').each(function() {
				$('#' + this.id).modal('hide');
			});
		}
	}

	var invokeFreshDialog = function(options) {
		$.closeDialog();
		options = $.extend(options,FRESHDIALOG.defaults);
		var invoked_from_DOM = typeof(options['element']) != 'undefined' && options['element'] != null ;

		if (invoked_from_DOM) {
			element = $(options['element']);
			if (element.data('dialog-loaded')) {

				modal = $('#' + element.data('dialog-id'));
				modal.modal('show');
				$('body').animate({scrollTop:0},300);
				return modal.attr('id');
			}

			options = $.extend(options, element.data());
			options['title'] = options['title'] || element.attr('title');
		} else if (typeof(options['id']) != 'undefined') {
			//We will return the Modal's id by default, so it can be invoked again using that.
			modal = $('#' + options['id']);
			modal.modal('show');
			return options['id'];
		}


		var element;
		// if (invoked_from_DOM){
			
		// 	for (var i=0; i<FRESHDIALOG.options_to_fetch.length; i++) {

		// 		if (typeof(element.data(FRESHDIALOG.options_to_fetch[i])) != 'undefined') {
		// 			options[FRESHDIALOG.options_to_fetch[i]] = element.data(FRESHDIALOG.options_to_fetch[i]);	
		// 		}
		// 	}
		// 	// //Special Handling for Title
		// 	options['title'] = options['title'] || element.attr('title');
		// 	
		// }

		var modal = $(FRESHDIALOG.template);
		modal.attr('id', FRESHDIALOG.id_keyword + '' + ++FRESHDIALOG.nextid);
		
		modal.find('.modal-header h3').text(options['title']);
		var modal_options = {
			backdrop: options['backdrop'],
			keyboard: options['keyboard'],
			show	: false
		}

		if (invoked_from_DOM) {
			if (element.data('target') === undefined) {
				var href = element.data('url') || element.attr('href');
				modal.find('.modal-body').load(href, function(responseText, textStatus, XMLHttpRequest) {
													
													modal.find('.modal-body').removeClass("loading-center");//.css({"height": "auto"});
												});
				
			} else {
				var target_element = $(element.data('target'));
				target_element.show().detach().appendTo(modal.find('.modal-body'));
				modal.find('.modal-body').removeClass("loading-center");
			}

			element.data('dialog-loaded', true);
			element.data('dialog-id',modal.attr('id'));
		} else {
			if (options['content'])
			var content = $(options['content']);
			content.detach().removeClass('hide').show();
			modal.find('.modal-body').html(content).removeClass('loading-center');

		}
		modal.addClass(options['classes']);
		modal.css({width: options['width'] + 30});

		//Removing the modal-backdrops
		// $('.modal-backdrop').remove();

		$(modal).modal(modal_options);
		modal.modal('show');
		$('body').animate({scrollTop:0},300);

		$(modal).on('click', '[rel=close-modal]', function(ev) {
			ev.preventDefault();
			modal.modal('hide');
		});

		return modal.attr('id');
	}

	$.fn.freshdialog = function(opts) {
		opts['content'] = this;
		opts['element'] = null;
		return invokeFreshDialog(opts);
	}
	$.freshdialog = function(opts) {
		if (typeof(opts['text']) != 'undefined') {
			opts['content'] = '<div>' + opts['text'] + '</div>';
		}
		opts['element'] = null;
		return invokeFreshDialog(opts);
	}

	$(document).ready(function() {
		$('body').on('click','[data-activate=dialog]',function(ev) { 
			ev.preventDefault();
			invokeFreshDialog({element: this});
		});
	});


})( jQuery );