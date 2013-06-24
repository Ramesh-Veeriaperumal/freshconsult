(function($) {

var activeForm, savingDraft, draftFirstFlag, draftClearedFlag, draftSavedTime,dontSaveDraft, replyEditor, draftInterval;

// ----- SAVING REPLIES AS DRAFTS -------- //
save_draft = function(content) {
	if ($.trim(content) != '') {
		$(".ticket_show #reply-draft").show().addClass('saving');
		$(".ticket_show #reply-draft").parent().addClass('draft_saved');

		$(".ticket_show #draft-save").text(TICKET_DETAILS_DATA['draft']['saving_text']);
		$(".ticket_show #clear-draft").hide();

		savingDraft = true;
		$.ajax({
			url: TICKET_DETAILS_DATA['draft']['save_path'],
			type: 'POST',
			data: {draft_data: content},
			success: function(response) {
				$(".ticket_show #draft-save").text(TICKET_DETAILS_DATA['draft']['saved_text']);
				$(".ticket_show #clear-draft").show();
				$(".ticket_show #reply-draft").removeClass('saving');
				draftSavedTime = new Date();
				savingDraft = false;
			}
		})
	}
}

autosaveDraft = function() {
	if(dontSaveDraft == 0 && TICKET_DETAILS_DATA['draft']['hasChanged']) {
		var content = $('#cnt-reply-body').getCode();

		if ($.trim(content) != '') 
			save_draft(content);
	}

	TICKET_DETAILS_DATA['draft']['hasChanged'] = false;
}

triggerDraftSaving = function() {
	dontSaveDraft = 0;
	draftInterval = setInterval(autosaveDraft, 30000);
}

stopDraftSaving = function() {
	dontSaveDraft = 1;
	clearInterval(draftInterval);
}

clearSavedDraft = function(){
	$.ajax({
		url: TICKET_DETAILS_DATA['draft']['clear_path'],
		type: 'delete'
	});
	TICKET_DETAILS_DATA['draft']['clearingDraft'] = true;
	$('#cnt-reply-body').setCode(TICKET_DETAILS_DATA['draft']['default_reply']);
	TICKET_DETAILS_DATA['draft']['hasChanged'] = false;
	$(".ticket_show #reply-draft").hide();
	$(".ticket_show #reply-draft").parent().removeClass('draft_saved');
	draftClearedFlag = true;
}

// ----- END OF DRAFT JS ---- //


var dontAjaxUpdate = false;

silenceTktFieldsUpdate = function() {
	dontAjaxUpdate = false;
}

unsilenceTktFieldsUpdate = function() {
	dontAjaxUpdate = true;
}

showHideDueByDialog = function(showHide){
	if(showHide){
		var duedate_container = $("#duedate-dialog-container").detach();
		$('#due-by-element-parent').append(duedate_container);
	   
		$("#duedate-dialog-container").show();
		$("#due-date-dialog").fadeIn();
		$("#due-date-dialog").position({
			of: $( "#due-by-element-parent" ),
			my: "right top",
			at: "left top"
		});
		
		$("#due-date-dialog").css({top: $("#due-date-dialog").position().top + 30 });
	}else{
		$("#due-date-dialog")
			.fadeOut(300, function(){
				$("#duedate-dialog-container").hide();
				var duedate_container = $("#duedate-dialog-container").detach();
				$('#Pagearea').append(duedate_container);
			});
	}
	$( "#edit-due-by-time" ).removeClass("highlight-text");
}




function dueDateSelected(date){
	new Date(date);
}

swapEmailNote = function(formid, link){
	$('#TicketPseudoReply').hide();
	

	if((activeForm != null) && ($(activeForm).get(0).id != formid))
		$("#"+activeForm.get(0).id).hide();


	activeForm = $('#'+formid).removeClass('hide').show();
	$.scrollTo('#'+formid, {offset: 100});
	if (activeForm.data('type') == 'textarea') {
		//For Facebook and Twitter Reply forms.
		setCaretToPos($('#' + formid + ' textarea').get(0), 0);
	} else {
		//For all other reply forms using redactor.
		invokeRedactor(formid+"-body",formid);
		$('#'+formid+"-body").getEditor().focus();
		if($.browser.mozilla){
			$('#'+formid+"-body").insertHtml("<div/>");//to avoid the jumping line on start typing 
		}
		$('#'+formid+"-body").getEditor().on('blur',function(){
			try{
				$('#'+formid+"-body").data('focus_node',document.getSelection().getRangeAt(0).endContainer);
				$('#'+formid+"-body").data('focus_node_offSet',document.getSelection().getRangeAt(0).endOffset);
			} catch (e) {}
		});
	}

	activeForm.trigger("visibility")

	//Draft Saving for Reply form
	if (formid == 'cnt-reply') {
		dontSaveDraft = false;
		if (!savingDraft && draftFirstFlag != 1){
			TICKET_DETAILS_DATA['draft']['hasChanged'] = false;
			triggerDraftSaving();
			if (!draftClearedFlag) {
				$("#draft-save").text(TICKET_DETAILS_DATA['draft']['saved_text']);
				$("#clear-draft").show();
				$("#reply-draft").show();
				$(".ticket_show #reply-draft").parent().addClass('draft_saved');
			}else{
				$("#reply-draft").hide();
				$(".ticket_show #reply-draft").parent().removeClass('draft_saved');
			}
		}
		draftFirstFlag = 1;
	} else {
		stopDraftSaving();
	}
}

insertIntoConversation = function(value){
	tweet_area = $('#cnt-tweet');
	element_id = $('#canned_response_show').data('editorId');

	if(tweet_area.css("display") == 'block'){
		get_short_url(value, function(bitly){
				insertTextAtCursor( $('#send-tweet-cnt-tweet-body'), bitly || value );
				$('#send-tweet-cnt-tweet-body')
						.trigger("focus")
						.trigger("keydown");
		});         
	}

	$('#canned_responses').modal('hide');

	if($("#" + element_id)){
			$("#"+element_id).getEditor().focus();
			$("#"+element_id).insertHtml(value);
	}    
	return;
}

getCannedResponse = function(ticket_id, ca_resp_id, element) {
	$(element).addClass("response-loading");
	$.ajax({
		type: 'POST',
		url: '/helpdesk/canned_responses/show/'+ticket_id+'?ca_resp_id='+ca_resp_id,
		contentType: 'application/text',
		dataType: "script",
		async: true,
		success: function(){
			$(element).removeClass("response-loading");
			$(element).qtip('hide');
			//$('[data-dismiss="modal"]').trigger('click');
			loadRecent();
		}
	});
	return true;
}

TICKET_DETAILS_DOMREADY = function() {

activeForm = null, savingDraft = false, draftFirstFlag = 0, draftClearedFlag = TICKET_DETAILS_DATA['draft']['cleared_flag'];

$('body').on("change.ticket_details", '#helpdesk_ticket_group_id' , function(e){
	$('#TicketProperties .default_agent')
		.addClass('loading-right');

	var group_id = $('#helpdesk_ticket_group_id').val();
	$.ajax({type: 'POST',
		url: '/helpdesk/commons/group_agents/' + group_id,
		contentType: 'application/text',
		success: function(data){
			$('#TicketProperties .default_agent select')
				.html(data)
				.trigger('change');

			$('#TicketProperties .default_agent').removeClass('loading-right');
		  }
	});
});

$('body').on('mouseover.ticket_details', ".ticket_show #draft-save", function() {
	if(savingDraft != 0){
	  jQuery(".ticket_show #draft-save").attr('title',humaneDate(draftSavedTime,new Date()));
	}
});

$("body").on("mouseout.ticket_details", ".ticket_show #draft-save",function(){
  $(".ticket_show #draft-save").attr('title','');
});

// This has been moved as a on click event directly to the cancel button 
// jQuery('input[type="button"][value="Cancel"]').bind('click', function(){cleardraft();});

$("body").on("click.ticket_details", ".ticket_show #clear-draft", function(){
  if (confirm(TICKET_DETAILS_DATA['draft']['clear_text']))
  	clearSavedDraft();
});

// Functions for Select2
var formatPriority = function(item) {
	return "<i class='priority_block priority_color_" + item.id + "'></i>" + item.text; 
}

var escapePriority = function (markup) {
	if (markup && typeof(markup) === "string") {
		return markup.replace(/&/g, "&amp;");
	}
	return markup;
}
var defaultSelect2Format = function(item) {
	return item.text.escapeHTML(); 
}

var formatTag = function(item) {
	return item.value;
}


// ----- CODE FOR REVERSE PAGINATION ------ //

var updateShowMore = function() {

	//Checking if it is Notes (true) or Activities (false)
	var showing_notes = $('#all_notes').length > 0;
	var total_count, loaded_items;
	if (showing_notes){
		loaded_items = $('[rel=activity_container] .conversation').length;
		total_count = TICKET_DETAILS_DATA['total_notes'];
	} else {
		total_count = TICKET_DETAILS_DATA['total_activities'];
		loaded_items = TICKET_DETAILS_DATA['loaded_activities'];
	}

	
	if (loaded_items < total_count) {
		var remaining_notes = total_count - loaded_items;
		$('#show_more [rel=count-total-remaining]').text(total_count - loaded_items);
		
		$('#show_more').removeClass('hide');
		return true;
	} else {
		$('#show_more').addClass('hide');
		return false;
	}
}

var updatePagination = function() {

	var showing_notes = $('#all_notes').length > 0;

	//Unbinding the previous handler:
	$('#show_more').off('click.ticket_details');
	$('#show_more').on('click.ticket_details',function(ev) {
		ev.preventDefault();
		$('#show_more').addClass('loading');
		var href;
		if (showing_notes)
			href = TICKET_DETAILS_DATA['notes_pagination_url'] + 'before_id=' + TICKET_DETAILS_DATA['first_note_id'];
		else
			href = TICKET_DETAILS_DATA['activities_pagination_url'] + 'before_id=' + TICKET_DETAILS_DATA['first_activity'];

		$.get(href, function(response) {

			TICKET_DETAILS_DATA['first_activity'] = null;
			TICKET_DETAILS_DATA['first_note_id'] = null;
			$('#show_more').removeClass('sloading loading-small').addClass('hide');
			$('[rel=activity_container]').prepend(response);
			
		});
	});
}

// ----- END FOR REVERSE PAGINATION ------ //

changeStatusTo = function(status) {
	$('#helpdesk_ticket_status option').prop('selected', false);
	$('#helpdesk_ticket_status option[value=' + status + ']').prop('selected', true);
	dontAjaxUpdate = true;
	$('#helpdesk_ticket_status').trigger('change');
}

refreshStatusBox = function() {
	$.ajax({
		url: TICKET_DETAILS_DATA['status_refresh_url'],
		success: function(response) {
			$('#due-by-element-parent').replaceWith(response)
			$('#due-by-element-parent').show('highlight',3000);
		}
	});
}

// For Setting Due-by Time


	$( "#due-date-picker" ).datepicker({
		showOtherMonths: true,
		selectOtherMonths: true,
		changeMonth: true,
		changeYear: true,
		onSelect: function(dateText, inst) {
			selectedDate = new Date(inst.selectedYear, inst.selectedMonth, inst.selectedDay);
			$("#due-date-value").html( selectedDate.toDateString() );
			CalcSelectedDateTime();
		}
	});
		
	$("#due-date-options").change(function(){
		if(this.value == 'specific')
			toggleDateCalender(true);
		else
			toggleDateCalender(false);
	});
	
	$("#due_by_hour, #due_by_minute, #due_by_am_pm").change(CalcSelectedDateTime);
		
	$("#set-date-time").click(function(){
		toggleDateCalender(true);
		$("#due-date-options").val("specific");
	});
		
	function toggleDateCalender(showOrHide){
		if(showOrHide){
			$("#due-date-button").hide();
			$("#due-date-calender").slideDown(300);
		}   
		else{
			$("#due-date-button").show();
			$("#due-date-calender").slideUp(300);
		}
	}
	
	$("#Pagearea").on('click', '#edit-dueby-time',function(){
		showHideDueByDialog(true);
	});
	
	$("#due-date-overlay").click(function(){
		showHideDueByDialog(false);
	});
	
	function CalcSelectedDateTime() {
		_date_time = $("#due-date-picker").datepicker("getDate"); 
		am_pm_val = $("#due_by_am_pm").val();
		hrs_val = parseInt($("#due_by_hour").val())
		
		if(hrs_val == 12 && am_pm_val == "AM") hrs_val = 0
		else if(am_pm_val == "PM" && hrs_val != 12) hrs_val += 12
		
		_date_time.setHours( hrs_val );
		_date_time.setMinutes( $("#due_by_minute").val() );
		
		if (TICKET_DETAILS_DATA['created_on'] > _date_time){
			$("#calender-buttons").hide();
			$("#calender-info").show();
		}else{
			$("#calender-buttons").show();
			$("#calender-info").hide();
		}               
		return _date_time;
	}
	
	$("#DueDateForm").submit(function(){  
		$("#calender-buttons").addClass("saving-items");
		_date_time = new Date();
		
		if($( "#due-date-options" ).val() == "specific"){
			_date_time = CalcSelectedDateTime();
		} 
		 
		$("#due_by_date_time").val(_date_time);
							
		$.post(this.action, $(this).serialize(), 
					function(data) {
						$("#edit-dueby-time-parent").html(data);
						showHideDueByDialog(false);
						$("#calender-buttons").removeClass("saving-items");
					});
		return false;
	});

// End of Due-by time JS

	if (jQuery('.requester-info-sprite').length < 2) {
		jQuery('.requester-info-sprite').parents('.tkt-tabs').remove();
	}
	
	$('body.ticket_details ul.tkt-tabs').each(function(){
		// For each set of tabs, we want to keep track of
		// which tab is active and it's associated content
		var $active, $content, $links = $(this).find('a');

		$active = $($links.filter('[href="'+location.hash+'"]')[0] || $links[0]);
		$active.parent().addClass('active');
		$content = $($active.attr('href'));

		// Hide the remaining content
		$links.not($active).each(function () {
			$($(this).attr('href')).hide();
		});

		// Bind the click event handler
		$(this).on('click.ticket_details', 'a', function(e){

			// Prevent the anchor's default click action
			e.preventDefault();

			// Make the old tab inactive.
			$active.parent().removeClass('active');
			$content.hide();

			// Update the variables with the new link and content
			$active = $(this);
			$content = $($(this).attr('href'));

			// Make the tab active.
			$active.parent().addClass('active');
			var widget_code = $content.find('textarea');
			$content.append(widget_code.val());
			widget_code.remove();
			$content.show();

		});

		$active.click();
	});


	$("body").on('change.ticket_details', '#helpdesk_ticket_group_id', function(e){
		$('#TicketProperties .default_agent')
			.addClass('sloading loading-small loading-right');

		$.ajax({type: 'POST',
			url: '/helpdesk/commons/group_agents/'+this.value,
			contentType: 'application/text',
			success: function(data){
				$('#TicketProperties .default_agent select')
					.html(data)
					.trigger('change');

				$('#TicketProperties .default_agent').removeClass('sloading loading-small loading-right');
			  }
		});
	});

	
	$("body").on('click.ticket_details', '.widget.load_on_click.inactive', function(ev){
		var widget_code = $(this).find('textarea');
		$(this).find('.content').append(widget_code.val());
		widget_code.remove();
		$(this).removeClass('inactive load_on_click');
	});

	$("body").on('click.ticket_details', '.widget.load_remote.inactive', function(ev){
		$(this).children('.content').trigger('afterShow');
		$(this).removeClass('inactive load_remote');
	});
	
	$("body").on('click.ticket_details', '.widget:not(.load_remote, .load_on_click, .dialog-widget) > h3', function(ev){
		$(this).parent().toggleClass('inactive');
	});

	$("body").on('click.ticket_details', '[rel=triggerAddTimer]', function(ev){
		ev.preventDefault();
		var timesheets = $('#timesheetlist');
		if(timesheets.length) {
			$('#triggerAddTime').trigger('click');
		} else {
			var timesheetTab = $('#TimesheetTab');
			if(timesheetTab.hasClass('load_remote'))  {
				timesheetTab.trigger('click.ticket_details');
			}
			$('#timesheets_loading').modal('show');
			var timesheetsLoading = setInterval(function() {
				
				if($('#timesheetlist').length) {
				
					$('#triggerAddTime').trigger('click');
					$('#timesheets_loading').modal('hide');
					clearInterval(timesheetsLoading);
				}
			}, 200);
		}
	});


	$("body.ticket_details .ticket_show select").data('placeholder','');
	$("#TicketProperties select.dropdown, #TicketProperties select.dropdown_blank, #TicketProperties select.nested_field, body.ticket_details select.select2").livequery(function(){
		if (this.id == 'helpdesk_ticket_priority') {
			$(this).select2({
				formatSelection: formatPriority,
				formatResult: formatPriority,
				escapeMarkup: escapePriority,
				specialFormatting: true,
				minimumResultsForSearch: 10
			});
		} else {
			$(this).select2({
				minimumResultsForSearch: 10
			}); 
		}
	});

	$('body.ticket_details [rel=tagger]').livequery(function() {
		$(this).select2({
			tags: TICKET_DETAILS_DATA['tag_list'],
			tokenSeparators: [',']
		});
	})


	// For Twitter Replybox
	$("body").on("change.ticket_details", '#twitter_handle', function (){
		twitter_handle= $('#twitter_handle').val();
		req_twt_id = $('#requester_twitter_handle').val();
		istwitter = $('#cnt-reply').data('isTwitter');
		if (!istwitter || req_twt_id == "" || twitter_handle == "")        
			return ;

		$.ajax({   
			type: 'POST',
			url: '/social/twitters/user_following?twitter_handle='+twitter_handle+'&req_twt_id='+req_twt_id,
			contentType: 'application/text', 
			async: false, 
			success: function(data){ 
				if (data.user_follows == true)
				{
					$('#tweet_type_selector').show();
					$('#not_following_message').hide();
				}
				else
				{
					$('#tweet_type_selector').hide();
					$('#not_following_message').show();
				}
			}
		});
	}); 

	//End of Twitter Replybox JS

	//For Clearing Bcc, Cc email list and hiding those containers
	$('body').on('click.ticket_details', '[rel=toggle_email_container]',function(ev) {
		ev.preventDefault();
		var container = $('#' + $(this).data('container'));
		var select = $('#' + $(this).data('container') + ' select');

		container.toggle();
		if (container.is(':visible')) {
			container.find('.search_field_item input').focus();
			$('#' + $(this).data('toggle-button')).hide();
		} else {
			$('#' + $(this).data('toggle-button')).show();
		}

		if (typeof($(this).data('clear')) != 'undefined' && $(this).data('clear') == true) {
			container.find('li.choice').remove();
			$('#' + $(this).data('toggle-checkbox')).prop('checked', false);
			$('#' + $(this).data('toggle-button')).show();
		} else {
			$('#' + $(this).data('toggle-checkbox')).prop('checked', true);
		}
	});


	//Hack for those who visit upon hitting the back button
	$('#activity_toggle').removeClass('active');
	$('#activity_toggle [rel=toggle]').prop('checked', false);
	$('body').on('click.ticket_details', '#activity_toggle', function(ev) {
		var _toggle = $(this);

		if (_toggle.hasClass('disabled')) return false;
		_toggle.addClass('disabled')
		var showing_notes = $('#all_notes').length > 0;
		var url = showing_notes ? TICKET_DETAILS_DATA['activities_pagination_url'] : TICKET_DETAILS_DATA['notes_pagination_url'];
		
		if (showing_notes) {
			TICKET_DETAILS_DATA['first_activity'] = null;
			TICKET_DETAILS_DATA['loaded_activities'] = 0;
		} else {
			TICKET_DETAILS_DATA['first_note_id'] = null;
			TICKET_DETAILS_DATA['total_notes'] = 0;
		}

		$('#show_more').addClass('hide').data('next-page',null);  //Resetting

		$.ajax({
			url: url,
			success: function(response) {
				$('[rel=activity_container]').replaceWith(response);
				$('#show_more').data('next-page',null);  //Resetting
				if (updateShowMore()) updatePagination();
				_toggle.removeClass('loading_activities disabled');
			}, 
			error: function(response) {
				$('#show_more').removeClass('hide');
				_toggle.toggleClass('active disabled');
			}
		})
	});

	$('body').on('click.ticket_details', '[rel=activity_container] .minimizable', function(ev){
		if ($(ev.target).is('a')) return;

		$(this).toggleClass('minimized');
	});

	$('body').on('click.ticket_details', '.collision_refresh', function(ev) {
		window.location = TICKET_DETAILS_DATA['ticket_path'];
	});

	$('body').on('click.ticket_details', ".conversation_thread .request_panel form .submit_btn", function(ev) {
		ev.preventDefault();
		$(this).parents('form').trigger('submit');
	});

	$('body').on('click.ticket_details', ".conversation_thread .request_panel form .cancel_btn", function(ev) {
		ev.preventDefault();
		if (ev.clientX == 0 && ev.clientY == 0) {
			return;
			/* Hack for Forward form.
			Scenario: When the user presses enter key while on the To field,
			the cancel btn is triggered.
			Difference b/w real trigger and this is clientX/Y values */
		}
		var btn = $(this);
		$('#' + btn.data('cntId')).hide().trigger('visibility');
		if (btn.data('showPseudoReply')) 
			$('#TicketPseudoReply').show();

		var _form = $('#' + btn.data('cntId') + " form");

		if (btn.data('clearDraft')) {
			clearSavedDraft();
			stopDraftSaving();
		}

		if (_form.data('cntId') && _form.data('destroyEditor')){
			$('#' + _form.data('cntId') + '-body').destroyEditor(); //Redactor
			_form.resetForm();
			_form.trigger('reset');
			_form.find('select.select2').trigger('change'); //Resetting select2

			//Removing the Dropbox attachments
			_form.find('.dropbox_div input[filelist]:not(.original_input)').remove();
		}

		if (_form.attr('rel') == 'forward_form')  {
			//Remove To Address
			_form.find('.forward_email li.choice').remove();
		}

	});

	$('body').on('click.ticket_details', '#time_integration .app-logo input:checkbox', function(ev) {
		$(this).parent().siblings('.integration_container').toggle($(this).prop('checked'));
	});

	function seperateQuoteText(_form){
		if(_form.data('fulltext')) {
			var body_text = jQuery('<div class="hide">'+jQuery('#' + _form.data('cntId') + '-body').val()+'</div>'); 
			jQuery("body").append(body_text);
			jQuery('#' + _form.data('cntId') + '-body-fulltext').val(body_text.html());
			body_text.find('div.freshdesk_quote').remove();
			jQuery('#' + _form.data('cntId') + '-body').val(body_text.html());
			body_text.remove();
		}
	}

	$('body').on('submit.ticket_details', ".conversation_thread .request_panel form", function(ev) {

		var _form = $(this);
		if (_form.valid()) {

			if (_form.attr('rel') == 'forward_form')  {
				//Check for To Addresses.              
				if (_form.find('input[name="helpdesk_note[to_emails][]"]').length == 0 )
				{
					alert('No email addresses found');
					return false;
				}
			}

			_form.find('input[type=submit]').prop('disabled', true);

			//Blocking the Form:
			if (_form.data('panel'))
			{	
				$('#' + _form.data('panel')).block({
					message: " <h1>...</h1> ",
					css: {
						display: 'none',
						backgroundColor: '#e9e9e9',
						border: 'none',
						color: '#FFFFFF',
						opacity:0
					},
					overlayCSS: {
						backgroundColor: '#e9e9e9',
						opacity: 0.6
					}
				});
			}

			if($.browser.msie) {
				stopDraftSaving();
				$.ajax({
					url: TICKET_DETAILS_DATA['draft']['clear_path'],
					type: 'delete'
				});
				seperateQuoteText(_form);
				return true;
			}
			ev.preventDefault();

			_form.ajaxSubmit({
				dataType: 'script',
				beforeSubmit: function(values, form) {
					var showing_notes = $('#all_notes').length > 0;

					var format = $('<input type="hidden" rel="ajax_params" name="format" value="js" />');
					_form.append(format);
					var input_showing = $('<input type="hidden" rel="ajax_params" name="showing" value="' + (showing_notes ? 'notes' : 'activities' ) + '" />');
					_form.append(input_showing);
					var input_since = $('<input type="hidden" rel="ajax_params" name="since_id" value="' + (showing_notes ? TICKET_DETAILS_DATA['last_note_id'] : TICKET_DETAILS_DATA['last_activity'] ) + '" />');
					_form.append(input_since);
					
					seperateQuoteText(_form);					

				},
				success: function(response) {
							
					var statusChangeField = jQuery('#reply_ticket_status_' + _form.data('cntId'));
					if(statusChangeField.length) {
						if(statusChangeField.val() != '') {
							refreshStatusBox();
							if(statusChangeField.val() == '4' || statusChangeField.val() == '5') {
								$('[rel=link_ticket_list]').click();
							}
							statusChangeField.val('')
						}
					}

					if (_form.data('panel')) {
						$('#' + _form.data('panel')).unblock();
						$('#' + _form.data('panel')).hide();
						$('#' + _form.data('panel')).trigger('visibility');
					}

					if (_form.data('cntId') && _form.data('cntId') == 'cnt-reply') {
						stopDraftSaving();
					}	

					if (_form.attr('rel') == 'edit_note_form')  {
						
						$('#note_details_' + _form.data('cntId')).html($(response).find("body-html").text());
						$('#note_details_' + _form.data('cntId')).show();
					}

					if (_form.data('cntId') && _form.data('destroyEditor')){
						$('#' + _form.data('cntId') + '-body').destroyEditor(); //Redactor
					}

					_form.resetForm();
					_form.trigger('reset');
					_form.find('select.select2').trigger('change'); //For resetting the values in Select2.

					if (_form.attr('rel') == 'forward_form')  {
						//Remove To Address
						_form.find('.forward_email li.choice').remove();
					}

					if (_form.attr('rel') == 'note_form')  {
						$('#toggle-note-visibility .toggle-button').addClass('active');
						var submit_btn = _form.find('.submit_btn');
						submit_btn.text(submit_btn.data('defaultText'));
					}

					//Enabling original attachments
					_form.find('.item[rel=original_attachment]').show();
					_form.find('input[rel=original_attachment]').prop('disabled', false);

					try {
						if (_form.data('cntId') && _form.data('cntId') == 'cnt-reply') {
							stopDraftSaving();
							clearSavedDraft();
						}	
					} catch(e) {}
					// The above block has been added so that Redactor errors do not restrict further flow.
					

					_form.find('[rel=ajax_params]').remove();
						
					_form.find('input[type=submit]').prop('disabled', false);
					if (_form.data('showPseudoReply')) {
						$('#TicketPseudoReply').show();
					}

				},
				error: function(response) {
					
					_form.find('input[type=submit]').prop('disabled', false);

					if (_form.data('panel')) {
						$('#' + _form.data('panel')).unblock();
					}


					if (_form.data('cntId') && _form.data('cntId') == 'cnt-reply') {
						triggerDraftSaving();
					}

				}
			});
		} else {
			_form.find('input[type=submit]').prop('disabled', false);
		}
	});

	$('body').on('click.ticket_details', '[rel=TicketReplyPlaceholder]', function(ev) {
		ev.preventDefault();
		$(this).hide();
		$('#ReplyButton').click();
	});

	//For showing canned response and solutions

	$('body').on('click.ticket_details', 'a[rel="ticket_canned_response"]', function(ev){
		ev.preventDefault();
		$('#canned_response_show').data('editorId', $(this).data('editorId'));
		$('#canned_response_show').trigger('click');
	});

	$('body').on('click.ticket_details', 'a[rel="ticket_solutions"]', function(ev){
		ev.preventDefault();
		$('#suggested_solutions_show').data('editorId', $(this).data('editorId'));
		$('#suggested_solutions_show').trigger('click');
	});

	//End

	//Toggling Note visiblity
	$('body').on('change.ticket_details', '#toggle-note-visibility input[type=checkbox]', function(ev){
		var submit_btn = $(this).parents('form').find('.submit_btn');
		if($(this).is(':checked')) {
			submit_btn.text(submit_btn.data('defaultText'));
		} else {
			submit_btn.text(submit_btn.data('publicText'));
		}
	});

	$('body').on('click.ticket_details', '.ticket_show #close_ticket_btn', function(ev){
		ev.preventDefault();
		var form = $("<form>")
			.attr("method", "post")
			.attr("action", $(this).attr('data-href') +"?disable_notification=" + ev.shiftKey )
			.appendTo(document.body);
		form.submit();
		return false;
	});

	$('body').on('change.ticket_details', '#custom_ticket_form', function(ev) {
		
		if (!dontAjaxUpdate) 
		{
			TICKET_DETAILS_DATA['updating_properties'] = true;
			$(ev.target).data('updated', true);
		}
		dontAjaxUpdate = false;
	} );

    $('body').on('click.ticket_details', '[rel=custom-reply-status]', function(ev){
      ev.preventDefault();
      ev.stopPropagation();
      jQuery('#reply_ticket_status_' + jQuery(this).data('cntId')).val(jQuery(this).data('statusVal'));
      jQuery('body').click();

      changeStatusTo(jQuery(this).data('statusVal'));
      $(this).parents('form').trigger('submit');
    });

    $('body').on('submit.ticket_details', '#custom_ticket_form', function(ev) {
    	
		ev.preventDefault(); 
		ev.stopPropagation();
		var tkt_form = $('#custom_ticket_form');
		if (tkt_form.valid()) {

			var submit = $('#custom_ticket_form .btn-primary');
			submit.button('loading');
			submit.attr('disabled','disabled');

			$.ajax({
				type: 'POST',
				url: tkt_form.attr('action'),
				data: tkt_form.serialize(),
				dataType: 'json',
				success: function(response) {
					TICKET_DETAILS_DATA['updating_properties'] = false;
					submit.val(submit.data('saved-text')).addClass('done');
					setTimeout( function() {
						submit.button('reset').removeClass('done');
					}, 2000);

					var updateStatusBox = false;
					if ($('.ticket_details #helpdesk_ticket_priority').data('updated') || $('.ticket_details #helpdesk_ticket_status').data('updated')) {
						$('.ticket_details .source-badge-wrap .source')
								.attr('class','')
								.addClass('source ')
								.addClass('priority_color_' + $('.ticket_details #helpdesk_ticket_priority').val())
								.addClass('status_' + $('.ticket_details #helpdesk_ticket_status').val());

						updateStatusBox = true;
					}

					if ($('.ticket_details #helpdesk_ticket_source').data('updated')) {

						$('.ticket_details .source-badge-wrap .source span')
								.attr('class','')
								.addClass('source_' + $('.ticket_details #helpdesk_ticket_source').val());

					}

					tkt_form.find('input, select, textarea').each(function() {
						$(this).data('updated', false);
					});

					if (updateStatusBox) {
						refreshStatusBox();
					}

				},
				error: function(jqXHR, textStatus, errorThrown) {
					submit.text(submit.data('default-text')).prop('disabled',false);
				}
			});
		}
			
	});

	


	// Scripts for ToDo List
	$('body').on('keydown.ticket_details', '.addReminder textarea', function(ev) {
		if(ev.keyCode == 13){
			ev.preventDefault();
			if(trim($(this).val()) != '') $(this).parents('form').submit();
		}
	});

	/*
		When the ticket subjects are long, we hide the extra content and show them only on mouseover. 
		While doing this, the ticket subject occupies more height that normal we are hiding that
		and showing that back on Mouseleave event.

		Being done to make sure that there is no visible jump in the infobox.
	*/
	// $('body').on('mouseenter.ticket_details', '.ticket_show .control-left h2.subject:not(.show_full)', function(){
	// 	if ($(this).height() > 30) {
	// 		$(this).siblings('.ticket-actions').hide();
	// 	}
	// });
	// $('body').on('mouseleave.ticket_details', '.ticket_show .control-left h2.subject:not(.show_full)', function() {
	// 	if (!$(this).siblings('.ticket-actions').is(':visible')) {
	// 		$(this).siblings('.ticket-actions').show();
	// 	}
	// })

	//Binding the Reply/Forward/Add Note buttons
	$('body').on('click.ticket_details', '[rel=note-button]', function(ev) {
		if (!$(this).parent().parent().hasClass('dropdown-menu')) {
			ev.preventDefault();
			ev.stopPropagation();
		}
		swapEmailNote('cnt-' + $(this).data('note-type'), this);
	})
	//ScrollTo the latest conversation

	if (updateShowMore()) updatePagination();

	//Previous Next Buttons request
	$.getScript("/helpdesk/tickets/prevnext/" + TICKET_DETAILS_DATA['displayId']);

	$('#twitter_handle').change();

	if(TICKET_DETAILS_DATA['scroll_to_last']) {
		$.scrollTo('[rel=activity_container] .conversation:last', { offset: $('#sticky_header').outerHeight() });
		$('#scroll-to-top').show();
	}

	//Hack for those who visit upon hitting the back button
	$('#activity_toggle').removeClass('active');
	jQuery('#activity_toggle').prop('checked', false);

	// Capturing the Unload and making sure everything is fine, before we let the 
	$(window).on('unload.ticket_details',function(e) {
		var messages = [];
		if ($('#custom_ticket_form .error:input').length > 0 ) {
			messages.push('There are errors in the form.');
		}
		
		if (TICKET_DETAILS_DATA['updating_properties']) {
			messages.push('Unsaved changes in the form');
		}

		if (TICKET_DETAILS_DATA['draft']['hasChanged'] && dontSaveDraft == 0) {
			autosaveDraft();
		}

		if (messages.length > 0) {
			var msg = '';
			messages.forEach(function(str) {
				msg += str + "\n";
			});

			e = e || window.event;
			if (e) {
				e.returnValue = msg;
			}

			return msg;
		}
	});

};

TICKET_DETAILS_UPDATE_FORM_SUBMIT = function() {
	var tkt_form = $('#custom_ticket_form');

	if (tkt_form.valid()) {
		
		var submit = $('#custom_ticket_form .btn-primary');
		submit.button('loading');
		submit.attr('disabled','disabled');

		$.ajax({
			type: 'POST',
			url: tkt_form.attr('action'),
			data: tkt_form.serialize(),
			dataType: 'json',
			success: function(response) {
				TICKET_DETAILS_DATA['updating_properties'] = false;
				submit.val(submit.data('saved-text')).addClass('done');
				setTimeout( function() {
					submit.button('reset').removeClass('done');
				}, 2000);

				var updateStatusBox = false;
				if ($('.ticket_details #helpdesk_ticket_priority').data('updated') || $('.ticket_details #helpdesk_ticket_status').data('updated')) {
					$('.ticket_details .source-badge-wrap .source')
							.attr('class','')
							.addClass('source ')
							.addClass('priority_color_' + $('.ticket_details #helpdesk_ticket_priority').val())
							.addClass('status_' + $('.ticket_details #helpdesk_ticket_status').val());

					updateStatusBox = true;
				}

				if ($('.ticket_details #helpdesk_ticket_source').data('updated')) {

					$('.ticket_details .source-badge-wrap .source span')
							.attr('class','')
							.addClass('source_' + $('.ticket_details #helpdesk_ticket_source').val());

				}

				tkt_form.find('input, select, textarea').each(function() {
					$(this).data('updated', false);
				});

				if (updateStatusBox) {
					refreshStatusBox();
				}

			},
			error: function(jqXHR, textStatus, errorThrown) {
				submit.text(submit.data('default-text')).prop('disabled',false);
			}
		});
	}

	return false;
};

TICKET_DETAILS_CLEANUP = function() {
	// if($('body').hasClass('ticket_details')) return;
	$("#TicketProperties select.dropdown, #TicketProperties select.dropdown_blank, #TicketProperties select.nested_field, body.ticket_details select.select2").expire();
	$('body.ticket_details [rel=tagger]').expire();
	jQuery('body').off('click.ticket_details')
    				.off('change.ticket_details')
    				.off('mouseover.ticket_details')
    				.off('mouseout.ticket_details')
    				.off('mouseenter.ticket_details')
    				.off('mouseleave.ticket_details')
    				.off('keydown.ticket_details')
    				.off('keyup.ticket_details')
    				.off('change.ticket_details')
    				.off('submit.ticket_details')
    jQuery(window).off('unload.ticket_details');

    jQuery('body').removeClass('ticket_details');

};


// MOVE TO !PATTERN
$('body').on('change.pattern', '.selected_to_yellow [type=radio], .selected_to_yellow [type=checkbox]', function(ev) {
	$(this).parents('.selected_to_yellow').find('.stripe-select').removeClass('stripe-select');
	$(this).parents('td').first().toggleClass('stripe-select', $(this).prop('checked'));
});

})(jQuery);