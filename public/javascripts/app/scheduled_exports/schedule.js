/*jslint browser: true, devel: true */
/*global  App */

window.App = window.App || {};
(function ($) {
	"use strict";

	var $body = $('body');

	App.Ticketschedule = {
		current_module: '',

		onFirstVisit: function (data) {
			this.onVisit(data);
		},

		onVisit: function (data) {
			this.setSubModule();
			if (this.current_module !== '') {
				this[this.current_module].onVisit();
			}
		},

		setSubModule: function() {
			switch (App.namespace) {
				case 'reports/scheduled_exports/index':
					this.current_module = "IndexSchedule";
					break;
				case 'reports/scheduled_exports/edit_activity':
					this.current_module = "EditActivity";
					break;
			}
		},

		onLeave: function (data) {
			if (this.current_module !== '') {
				this.current_module = '';
			}
		},

		initEmail: function(){
			var $emailField = $('#email_recipients'), _this = this;
			if($emailField.length > 0){
				$emailField.select2({
					maximumSelectionSize: 10,
					ajax: {
						url: "/search/autocomplete/requesters",
						dataType: 'json',
						delay: 250,
						cache : false,
						data: function(term, page) {
							return {
								q: term, // search term
							};
						},
						results: function(data, params) {
							var results = [];
							jQuery.each(data.results, function(index, item){
								if(item.email){
									results.push(_this.setData(item));
								}
							});
							return {
								results: results
							};
						}
					},
					multiple: true,
					minimumInputLength: 2,
					initSelection: function(element, callback) {
						var initData = [];
						if(ticketSchedule.email_recipients &&  ticketSchedule.email_recipients[0]){
							ticketSchedule.email_recipients.each(function(item){
								initData.push(_this.setData(item));
							});
						}else{
							if(ticketSchedule.current_user_recipients &&  ticketSchedule.current_user_recipients[0]){
								initData.push(_this.setData(ticketSchedule.current_user_recipients[0]));
							}
						}
						callback(initData);
					}
				});
			}
		},
		setData: function(item){
			var obj = {};
			if(item){
				obj = {
					id: item.id,
					text: item.details,
					email : item.email
				}
			}
			return obj;
		},

		fieldsToggle: function(source){
			var fieldClass = '.'+ source +'-fields',fieldItemClass = fieldClass + '-item';
			$(fieldItemClass).slideToggle();
			$( fieldClass + ' .ficon-caret-down').toggleClass('hide');
			$( fieldClass + ' .ficon-caret-right').toggleClass('hide');
		},

		emailAPIToggle: function(){
			$('.email-content').toggle();
			$('.api-content').toggle();
		},

		checkedFieldText: function(count){
			var text;
			switch(count){
				case 0:
					text = I18n.t('helpdesk_reports.ticket_schedule.new.field_selected',{count: count });
					break;
				default:
					text = ( count+ ' ' + I18n.t('helpdesk_reports.ticket_schedule.new.field_selected',{count: count }));
			}
			return text
		},

		constructScheduleTime: function() {
    	var $el = $(".schedule-time");
    	jQuery($el).empty();

      for(var i = 0 ; i <= 23 ; i++) {
          $el.append(jQuery('<option>', {
              value: i,
              text: i + ":00"
          }));
      }
      $('.schedule-message').html(I18n.t('helpdesk_reports.ticket_schedule.new.schedule_message',{zone: ticketSchedule.user_time_zone,label: I18n.t('helpdesk_reports.ticket_schedule.new.daily_label') }));
    },

		changeFieldLabel: function(field,selectAll){
			var $element = $('.'+field).find('.selected-label'),
					checkedLength,
					fieldText,
					selectAllValue = $('.'+ field + '-item .select-all').is(':checked');
			if(selectAll){
				$('.'+ field + '-item input:checkbox').prop('checked',selectAllValue);
			}
			if(!selectAll && selectAllValue){
				$('.'+ field + '-item input:checkbox.select-all').prop('checked',!selectAllValue)
			}
			checkedLength = $('.'+ field + '-item input:checkbox:checked:not(.select-all)').length,
			fieldText = this.checkedFieldText(checkedLength)
			$element.text(fieldText);
		},

		copyClipboard: function(){
			var clipboard = new Clipboard('.copy-clip', {
			    target: function(trigger) {
			      return $(trigger).siblings("input.clip-data")[0];
			    }
			});

			clipboard.on('success', function(e) {
				$(e.trigger).html('<i class="ficon-tick fsize-18"></i>').attr('data-original-title', "Copied").data('copied',true).twipsy('show');
				setTimeout(function(){
					$(e.trigger).twipsy('hide').html('<i class="ficon-clone fsize-18"></i>').attr('data-original-title', "Copy to clipboard").data('copied',false);
				},1000);
				setTimeout(function(){
					$(e.trigger).twipsy('hide').html('<i class="ficon-clone fsize-18"></i>').attr('data-original-title', "Copy to clipboard").data('copied',false);
				},1000)
			  e.clearSelection();
			});

			$body.on('focus.ticket-schedule', '.clip-data', function () {
				$(this).select();
			});
		},

		disableButton: function(source){
			var $btnSave = $('.schedule-save');
			if(source === 'save'){
				$btnSave.text($btnSave.data('loading-text'))
			}
			$btnSave.attr('disabled',true);
			$('.cancel').attr('disabled',true)
		},

		scheduleValueChange: function(){
			var $scheduleStateElement = $('.schedule-state'),
				$scheduleTimeElement = $('.schedule-time');
			$scheduleStateElement.trigger('change');
			this.changeFieldLabel('ticket-fields');
			$scheduleStateElement.val(ticketSchedule.frequency).trigger('change');
			if(ticketSchedule.minute_of_day && ticketSchedule.day_of_export){
				$scheduleTimeElement.val(ticketSchedule.minute_of_day).trigger('change');
				$('.schedule-day').val(ticketSchedule.day_of_export).trigger('change');
			}else{
				$scheduleTimeElement.val(ticketSchedule.minute_of_day).trigger('change');
			}
			if($('.contact-fields-item input:checkbox:checked').length){
				this.fieldsToggle('contact');
				this.changeFieldLabel('contact-fields');
			}
			if($('.company-fields-item input:checkbox:checked').length){
				this.fieldsToggle('company');
				this.changeFieldLabel('company-fields');
			}
			this.initSelectAllFields();
			if(ticketSchedule.email_recipients && ticketSchedule.email_recipients[0]){
				$('#email_recipients').val(ticketSchedule.email_recipients[0].id).trigger('change')
			}
		},

		initSelectAllFields: function(){
			if($('.ticket-fields-item input:checkbox:not(".select-all")').length === $('.ticket-fields-item input:checkbox:not(".select-all"):checked').length){
				$('.ticket-fields-item .select-all').prop('checked',true);
			}
			if($('.contact-fields-item input:checkbox:not(".select-all")').length === $('.contact-fields-item input:checkbox:not(".select-all"):checked').length){
				$('.contact-fields-item .select-all').prop('checked',true);
			}
			if($('.company-fields-item input:checkbox:not(".select-all")').length === $('.company-fields-item input:checkbox:not(".select-all"):checked').length){
				$('.company-fields-item .select-all').prop('checked',true);
			}
		},

		bindEvents: function(){
			var _this = this;
			$body.on('click.ticket-schedule','.ticket-fields',function(){
				_this.fieldsToggle('ticket');
			});
			$body.on('click.ticket-schedule','.contact-fields',function(){
				_this.fieldsToggle('contact');
			});
			$body.on('click.ticket-schedule','.company-fields',function(){
				_this.fieldsToggle('company');
			});
			$body.on('change.ticket-schedule','input[name="scheduled_export[schedule_details][delivery_type]"]',function(){
				_this.emailAPIToggle();
			});
			$body.on('change.ticket-schedule','.export-fields-item input:checkbox',function(e){
				var $srcElement = $(this);
				_this.changeFieldLabel($srcElement.data('field'),$srcElement.data('select-all'));
			});
			$body.on('change.ticket-schedule','.schedule-state', function(){
				var value = $(this).val(),label,zone;
				switch(value){
					case "0":
						$('.schedule-time,.schedule-time-at').removeClass('schedule-time-show').prop('disabled',true);
						$('.schedule-day,.schedule-day-on').removeClass('schedule-day-show').prop('disabled',true);
						zone = '';label = I18n.t('helpdesk_reports.ticket_schedule.new.hour_label');
						break;
					case "1":
						$('.schedule-day,.schedule-day-on').removeClass('schedule-day-show').prop('disabled',true);
						$('.schedule-time,.schedule-time-at').addClass('schedule-time-show').prop('disabled',false);
						zone = ticketSchedule.user_time_zone;
						label = I18n.t('helpdesk_reports.ticket_schedule.new.daily_label');
						break;
					case "2":
						$('.schedule-time,.schedule-time-at').addClass('schedule-time-show').prop('disabled',false);
						$('.schedule-day,.schedule-day-on').addClass('schedule-day-show').prop('disabled',false);
						zone =ticketSchedule.user_time_zone;
						label = I18n.t('helpdesk_reports.ticket_schedule.new.weekly_label');
						break;
				}
				$('.schedule-message').html(I18n.t('helpdesk_reports.ticket_schedule.new.schedule_message',{zone: zone,label: label }))
			});
		},

		bindToggleEvents: function(){
			var _this = this;
			$body.on('change.ticket-schedule','.ticket_activity-toggle', function(e){
		    var value = $(this).is(':checked'),
					url = $(this).data('url');
		    jQuery.ajax({
		      url: url,
		      method: "POST",
		      data:{
		        "scheduled_activity_export[active]": value
		      },
		      success: function(result){
		      }
		    });

		  });
			$body.on('submit.ticket-schedule','#editActivityForm',function(){
				_this.disableToggleBtn();
				_this.disableButton('save');
			});
			$body.on('click.ticket-schedule','.cancel',function(){
				_this.disableToggleBtn();
				_this.disableButton('cancel');
			});
		},
		disableToggleBtn: function(){
			$('.toggle-button').addClass('disabled');
		},

		unbindEvents: function(){
			$body.off('.ticket-schedule');
		}
	}
})(jQuery);
