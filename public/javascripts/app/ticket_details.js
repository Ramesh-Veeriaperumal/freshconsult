(function($) {
// Initialisation
TICKET_DETAILS_DATA['updating_properties'] = false;
//Ticket Properties Update Ajax Function
var ticket_update_timeout;
var tmp_count = 0;



// ----- SAVING REPLIES AS DRAFTS -------- //
var savingDraft = false, draftFirstFlag = 0, draftClearedFlag = TICKET_DETAILS_DATA['draft']['cleared_flag'];
var draftSavedTime,dontSaveDraft, replyEditor, draftInterval;


save_draft = function(content) {
	if ($.trim(content) != '') {
		$(".ticket_show #reply-draft").show().addClass('saving');
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
	draftClearedFlag = true;
}

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


// ----- END OF DRAFT JS ---- //

//Agents updation on Group Change.


var dontAjaxUpdate = false;
var deferredTicketUpdate = function(timeout) {
	timeout = timeout || 3000;
	if (typeof(ticket_update_timeout) != 'undefined') {
		clearTimeout(ticket_update_timeout);
	}

	// if ($('#custom_ticket_form').valid()) {
	//     ticket_update_timeout = setTimeout(function() {
	//         $('#custom_ticket_form').submit();
	//     },3000);
	// }

}

showHideDueByDialog = function(showHide){
	if(showHide){
		var duedate_container = $("#duedate-dialog-container").detach();
		$('#ticket_status_box').append(duedate_container);
	   
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


showHideEmailContainer = function(){
	$(".ccEmailMoreContainer").toggle();
	if($(".ccEmailMoreContainer").css("display") == "inline"){
		$(".ccEmailMoreLink").text('');
	}
}

showHideToEmailContainer = function(){
	$(".toEmailMoreContainer").toggle();
	if($(".toEmailMoreContainer").css("display") == "inline"){
		$(".toEmailMoreLink").text('');
	}
}

changeStatusToResolved = function() {
	$('#helpdesk_ticket_status option').prop('selected', false);
	$('#helpdesk_ticket_status option[value=4]').prop('selected', true);
	dontAjaxUpdate = true;
	$('#helpdesk_ticket_status').trigger('change');
}

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

$('#helpdesk_ticket_group_id').bind("change", function(e){
	$('#TicketProperties .default_agent')
		.addClass('loading-right');

	$.ajax({type: 'POST',
		url: '/helpdesk/commons/group_agents/'+this.value,
		contentType: 'application/text',
		success: function(data){
			$('#TicketProperties .default_agent select')
				.html(data)
				.trigger('change');

			$('#TicketProperties .default_agent').removeClass('loading-right');
		  }
	});
});

function dueDateSelected(date){
	new Date(date);
}

var fetchLatestNotes = function() {
	var href;
	var showing_notes = $('#all_notes').length > 0;
	if (showing_notes) {
		href = TICKET_DETAILS_DATA['notes_pagination_url'] + 'since_id=' + TICKET_DETAILS_DATA['last_note_id'];
	} else {
		href = TICKET_DETAILS_DATA['activities_pagination_url'] + 'since_id=' + TICKET_DETAILS_DATA['last_activity'];
	}
	 
	$.ajax({
		url: href,
		type: 'GET',
		success: function(response) {
			$('[rel=activity_container]').append(response);
		}
	});
}
//   Copied from Old Show Page
var activeForm = null;
swapEmailNote = function(formid, link){
	$('#TicketPseudoReply').hide();
	

	if((activeForm != null) && ($(activeForm).get(0).id != formid))
		$("#"+activeForm.get(0).id).hide();


	activeForm = $('#'+formid).removeClass('hide').show();
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
			}else{
				$("#reply-draft").hide();
			}
		}
		draftFirstFlag = 1;
	} else {
		stopDraftSaving();
	}
}

var activeTinyMce = null;
showCannedResponse = function(button, ticket_id){
	$("#canned_response_container").css($(button).offset());

	activeTinyMce = $(button).data("tinyMceId") || "";
	
	$("#canned_response_container")    
		.show()
		.addClass("loading");

	$("#canned_response_list")
		.load("/helpdesk/canned_responses/index/"+ticket_id, function(){
			$("#canned_response_container")
				.removeClass("loading");
		})
		.show();        
}

	 
insertIntoConversation = function(value,element_id){
	note_area  = $('#cnt-note');
	reply_area = $('#cnt-reply');
	fwd_area = $('#cnt-fwd')
	tweet_area = $('#cnt-tweet');

	if(element_id == undefined){
		 if(reply_area.css('display')== 'block') {
			 element_id = "cnt-reply-body";
		}
		else if (note_area.css('display') =='block'){
			element_id = "cnt-note-body";
		}
	}
	if(tweet_area.css("display") == 'block'){
		get_short_url(value, function(bitly){
				insertTextAtCursor( $('#send-tweet-cnt-tweet-body'), bitly || value );
				$('#send-tweet-cnt-tweet-body')
						.trigger("focus")
						.trigger("keydown");
		});         
	}
	if(jQuery(element_id)){
			jQuery("#"+element_id).getEditor().focus();
			jQuery("#"+element_id).insertHtml(value);
	}        

	return;
}

getCannedResponse = function(ticket_id, ca_resp_id, element) {
	$("#canned_response_container").addClass("loading")
	$(element).addClass("response-loading");
	$.ajax({
		type: 'POST',
		url: '/helpdesk/canned_responses/show/'+ticket_id+'?ca_resp_id='+ca_resp_id,
		contentType: 'application/text',
		async: false,
		success: function(data){	
			insertIntoConversation(data);
			$(element).removeClass("response-loading");
			$(element).qtip('hide');
			$('.ui-icon-closethick').trigger('click');

		}
	});
	return true;
}
//  End of Old Show page copy


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

	if (updateShowMore()) {
		var showing_notes = $('#all_notes').length > 0;

		//Unbinding the previous handler:
		$('#show_more').off('click');
		$('#show_more').on('click',function(ev) {
			ev.preventDefault();
			$('#show_more').addClass('loading');
			var href;
			if (showing_notes)
				href = TICKET_DETAILS_DATA['notes_pagination_url'] + 'before_id=' + TICKET_DETAILS_DATA['first_note_id'];
			else
				href = TICKET_DETAILS_DATA['activities_pagination_url'] + 'before_id=' + TICKET_DETAILS_DATA['first_activity'];

			$.get(href, function(response) {
				$('#show_more').removeClass('loading');
				$('[rel=activity_container]').prepend(response);
				$('#show_more').data('next-page',$('#show_more').data('next-page') + 1);
				updateShowMore();
			});
		});
		
	}   
}

// ----- END FOR REVERSE PAGINATION ------ //

$(document).ready(function() {


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

	$('ul.tkt-tabs').each(function(){
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
		$(this).on('click', 'a', function(e){

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
	
	$("body").on('click.ticket_details', '.widget.load_on_click.inactive', function(ev){
		var widget_code = $(this).find('textarea');
		$(this).find('.content').append(widget_code.val());
		widget_code.remove();
		$(this).removeClass('inactive');
	});

	$("body").on('click.ticket_details', '.widget.load_remote.inactive', function(ev){
		$(this).children('.content').trigger('afterShow');
		$(this).removeClass('inactive');
	});

	$("select").data('placeholder','');
	$("#TicketProperties select.dropdown, #TicketProperties select.dropdown_blank, #TicketProperties select.nested_field, select.select2").livequery(function(){
		if (this.id == 'helpdesk_ticket_priority') {
			$(this).select2({
				formatSelection: formatPriority,
				formatResult: formatPriority,
				escapeMarkup: escapePriority,
				specialFormatting: true,
				minimumResultsForSearch: 5
			});
		} else {
			$(this).select2({
				minimumResultsForSearch: 5
			}); 
		}
	});

	$('[rel=tagger]').livequery(function() {
		$(this).select2({
			tags: TICKET_DETAILS_DATA['tag_list'],
			tokenSeparators: [',']
		});
	})


	// For Twitter Replybox
	$("body").on("change.ticket_details", '#twitter_handle', function (){
		twitter_handle= $('#twitter_handle').val();
		req_twt_id = $('#requester_twitter_handle').val();
		istwitter = $('#cnt-tweet').data('isTwitter');
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

	//Loading Ticket Activities
	$('body').on('change.ticket_details', '.ticket_show #activity_toggle input[type=checkbox]', function(ev) {

		ev.preventDefault();
		var _toggle = $(this).parent();
		var _checkbox = $(this);
		_toggle.addClass('loading_activities');

		var showing_notes = $('#all_notes').length > 0;
		var url = showing_notes ? TICKET_DETAILS_DATA['activities_pagination_url'] : TICKET_DETAILS_DATA['notes_pagination_url'];
		

		$('#show_more').addClass('hide').data('next-page',null);  //Resetting

		$.ajax({
			url: url,
			success: function(response) {
				$('[rel=activity_container]').replaceWith(response);
				$('#show_more').data('next-page',null);  //Resetting
				updatePagination();
				_toggle.removeClass('loading_activities');
			}, 
			error: function(response) {
				$('#show_more').removeClass('hide');
				_checkbox.prop('checked', !_checkbox.prop('checked'));
				_toggle.removeClass('loading_activities')
				_checkbox.next().toggleClass('active');
			}
		})
	});

	$('.ticket_details').on('click.ticket_details', '[rel=activity_container] .minimizable', function(){
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
		var btn = $(this);
		$('#' + btn.data('cntId')).hide().trigger('visibility');
		$('#' + btn.data('cntId') + '-body').destroyEditor();
		if (btn.data('showPseudoReply')) 
			$('#TicketPseudoReply').show();
		if (btn.data('clearDraft')) {
			clearSavedDraft();
			stopDraftSaving();
		}
	});

	$('body').on('click.ticket_details', '#time_integration .app-logo input:checkbox', function(ev) {
		$(this).parent().siblings('.integration_container').toggle($(this).prop('checked'));
	});

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
						backgroundColor: '#FFFFFF',
						border: 'none',
						color: '#FFFFFF'
					},
					overlayCSS: {
						backgroundColor: '#FFFFFF',
						opacity: 0.6
					}
				});
			}

			if ($('html').hasClass('ie6') || $('html').hasClass('ie7') || $('html').hasClass('ie8') || $('html').hasClass('ie9')) {
				stopDraftSaving();
				$.ajax({
					url: TICKET_DETAILS_DATA['draft']['clear_path'],
					type: 'delete'
				});
				return true;
			}
			ev.preventDefault();

			_form.ajaxSubmit({
				dataType: 'script',
				beforeSubmit: function(values, form) {
					var showing_notes = $('#all_notes').length > 0;

					var format = $('<input type="hidden" rel="ajax_params" name="format" value="js" />');
					_form.append(format);
					var input_xhr = $('<input type="hidden" rel="ajax_params" name="xhr" value="true" />');
					_form.append(input_xhr);
					var input_showing = $('<input type="hidden" rel="ajax_params" name="showing" value="' + (showing_notes ? 'notes' : 'activities' ) + '" />');
					_form.append(input_showing);
					var input_since = $('<input type="hidden" rel="ajax_params" name="since_id" value="' + (showing_notes ? TICKET_DETAILS_DATA['last_note_id'] : TICKET_DETAILS_DATA['last_activity'] ) + '" />');
					_form.append(input_since);

				},
				success: function(response) {

					if (_form.data('panel')) {
						$('#' + _form.data('panel')).unblock();
						$('#' + _form.data('panel')).hide();
						$('#' + _form.data('panel')).trigger('visibility');
					}

					if (_form.attr('rel') == 'edit_note_form')  {
						
						$('#note_details_' + _form.data('cntId')).html($(response).find("body-html").text());
						$('#note_details_' + _form.data('cntId')).show();
					}


					if (_form.data('cntId') && _form.data('destroyEditor')){
						$('#' + _form.data('cntId') + '-body').destroyEditor(); //Redactor
						_form.resetForm();
					}

					try {
						if (_form.data('cntId') && _form.data('cntId') == 'cnt-reply') {
							stopDraftSaving();
							clearSavedDraft();
						}	
					} catch(e) {}
					// The above block has been added so that Redactor errors do not restrict further flow.
					

					_form.find('[rel=ajax_params]').remove();
						
					_form.find('input[type=submit]').prop('disabled', false);
					if (_form.data('showPseudoReply'))
						$('#TicketPseudoReply').show();


				},
				error: function(response) {
					
					_form.find('input[type=submit]').prop('disabled', false);

					if (_form.data('panel')) {
						$('#' + _form.data('panel')).unblock();
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

	// -----   START OF TICKET BAR FIXED TOP ------ //
	//For having the ticket subject and the action bar floating at the top when Scrolling down	
	var REAL_TOP = $("#wrap .header").first().height() + 10;
	var outerHeight = $('.fixedStrap').outerHeight();
	var the_window = $(window);

	the_window.on('scroll.ticket_details', function () {
		if (the_window.scrollTop() > REAL_TOP) {
			if (!$('.fixedStrap').hasClass('at_the_top')) {

				$('.fixedStrap, .fixedbg').addClass('at_the_top');
				$('#forFixed').show();
				$('.fixedStrap, .fixedbg').css({top: -outerHeight}).animate({ top: 0}, 500);
				$('#firstchild').addClass('firstchild');
			}

		} else {
			$('.fixedStrap, .fixedbg').removeClass('at_the_top').css({top: ''});
			$('#forFixed').hide();
			$('#firstchild').removeClass('firstchild');
		}
	});
	// -----   END OF TICKET BAR FIXED TOP ------ //

	//Toggling Note visiblity
	$('body').on('click.ticket_details', '#toggle-note-visibility', function(ev){
		var checkbox = $(this).find('input[type=checkbox]');
		checkbox.prop("checked", !checkbox.prop("checked"));
		$(this).toggleClass('visible');
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

	$('#custom_ticket_form').on('change.ticket_details',function(ev) {
		if (!dontAjaxUpdate) 
		{
			$('#helpdesk_ticket_submit').show();
			TICKET_DETAILS_DATA['updating_properties'] = true;
			$(ev.target).data('updated', true);
			// var submit_timeout = 1500;
			// if (ev.target.id == 'helpdesk_ticket_group_id') {
			//     return true;
			//     //Avoiding Updates firing for changes to Group Field
			//     //This will be fired after the Agents are loaded.
			// }

			
			// deferredTicketUpdate(submit_timeout);
		}
		dontAjaxUpdate = false;
	} );

    $('.ticket_details').on('click.ticket_details', '[rel=custom-reply-status]', function(ev){
      ev.preventDefault();
      ev.stopPropagation();
      jQuery('#reply_ticket_status_' + jQuery(this).data('cntId')).val(jQuery(this).data('statusVal'));
      jQuery('body').click();

      changeStatusTo(jQuery(this).data('statusVal'));
      jQuery("#HelpdeskReply").trigger('submit');
    });

	$('#custom_ticket_form').on('submit.ticket_details', function(ev) {
		ev.preventDefault(); 
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
					if ($('.ticket_show #helpdesk_ticket_priority').data('updated') || $('.ticket_show #helpdesk_ticket_status').data('updated')) {
						$('.ticket_show .source-badge-wrap .source')
								.attr('class','')
								.addClass('source ')
								.addClass('priority_color_' + $('.ticket_show #helpdesk_ticket_priority').val())
								.addClass('status_' + $('.ticket_show #helpdesk_ticket_status').val());

						updateStatusBox = true;
					}

					if ($('.ticket_show #helpdesk_ticket_source').data('updated')) {

						$('.ticket_show .source-badge-wrap .source span')
								.attr('class','')
								.addClass('source_' + $('.ticket_show #helpdesk_ticket_source').val());

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
					// console.log('Errors');
					// console.log(jqXHR);
					// console.log(textStatus);
					// console.log(errorThrown);
				}
			});
		}
			
	});

	/*
		When the ticket subjects are long, we hide the extra content and show them only on mouseover. 
		While doing this, the ticket subject occupies more height that normal we are hiding that
		and showing that back on Mouseleave event.

		Being done to make sure that there is no visible jump in the infobox.
	*/
	$('body').on('mouseenter.ticket_details', '.ticket_show .control-left h2.subject:not(.show_full)', function(){
		if ($(this).height() > 30) {
			$(this).siblings('.ticket-actions').hide();
		}
	});
	$('body').on('mouseleave.ticket_details', '.ticket_show .control-left h2.subject:not(.show_full)', function() {
		if (!$(this).siblings('.ticket-actions').is(':visible')) {
			$(this).siblings('.ticket-actions').show();
		}
	})

	//Binding the Reply/Forward/Add Note buttons
	$('.ticket_show').on('click.ticket_details', '[rel=note-button]', function(ev) {
		ev.preventDefault();
		ev.stopPropagation();
		swapEmailNote('cnt-' + $(this).data('note-type'), this);
	})
	//ScrollTo the latest conversation

	updatePagination();

	//Previous Next Buttons request
	$.getScript("/helpdesk/tickets/prevnext/" + TICKET_DETAILS_DATA['displayId']);

	// setInterval(function() { $('.btn-toolbar').toggle().toggle(); }, 500); //Hack for Bootstrap buttons repositioning in Chrome
});


// MOVE TO !PATTERN
$('body').on('change.pattern', '.selected_to_yellow [type=radio], .selected_to_yellow [type=checkbox]', function(ev) {
	$(this).parents('.selected_to_yellow').find('.stripe-select').removeClass('stripe-select');
	$(this).parents('td').first().toggleClass('stripe-select', $(this).prop('checked'));
});

// Capturing the Unload and making sure everything is fine, before we let the 
window.onbeforeunload = function(e) {
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
		console.log(msg);
		e = e || window.event;
		if (e) {
			e.returnValue = msg;
		}

		return msg;
	}
};
})(jQuery);