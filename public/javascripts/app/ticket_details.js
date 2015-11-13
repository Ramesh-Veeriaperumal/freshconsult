(function($) {

var activeForm, savingDraft, draftClearedFlag, draftSavedTime,dontSaveDraft, replyEditor, draftInterval, currentStatus;
var MAX_EMAILS = 50;
// ----- SAVING REPLIES AS DRAFTS -------- //
save_draft = function(content, cc_email_list, bcc_email_list) {
	if ($.trim(content) != '') {
		$(".ticket_show #reply-draft").show().addClass('saving');
		$(".ticket_show #reply-draft").parent().addClass('draft_saved');

		$(".ticket_show #draft-save").text(TICKET_DETAILS_DATA['draft']['saving_text']);
		savingDraft = true;
		$.ajax({
			url: TICKET_DETAILS_DATA['draft']['save_path'],
			type: 'POST',
			data: {draft_data: content,
			       draft_cc: cc_email_list,
			       draft_bcc: bcc_email_list},
			success: function(response) {
				$(".ticket_show #draft-save")
					.text(TICKET_DETAILS_DATA['draft']['saved_text'])
					.attr('data-moment', new Date());
				$(".ticket_show #reply-draft").removeClass('saving');				
				savingDraft = false;
				TICKET_DETAILS_DATA['draft']['saved'] = true;
			}
		})
	}
}

autosaveDraft = function() {
	if(dontSaveDraft == 0 && TICKET_DETAILS_DATA['draft']['hasChanged']) {
		var content = $('#cnt-reply-body').getCode();

		var cc_email_list = "";
		$("#cc-form-container-cnt-reply input[name='helpdesk_note[cc_emails][]']").each(function(idx,elem){
						cc_email_list = cc_email_list + elem.value + ';'
					});
		if (cc_email_list.length > 0)
			cc_email_list = cc_email_list.substr(0, cc_email_list.length - 1) ;

		var bcc_email_list = "";
		$("#bcc-form-container-cnt-reply input[name='helpdesk_note[bcc_emails][]']").each(function(idx,elem){
						bcc_email_list = bcc_email_list + elem.value + ';'
					});
		if(bcc_email_list.length > 0)
		  bcc_email_list = bcc_email_list.substr(0,bcc_email_list.length - 1);
		if ($.trim(content) != '' || cc_email_list.length > 0 || bcc_email_list.length > 0)
			save_draft(content, cc_email_list, bcc_email_list);
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

var _clearDraftDom = function() {
	$(".ticket_show #reply-draft").hide();
	$(".ticket_show #reply-draft").parent().removeClass('draft_saved');
	draftClearedFlag = true;
}
clearSavedDraft = function(editorId){
	$.ajax({
		url: TICKET_DETAILS_DATA['draft']['clear_path'],
		type: 'delete'
	});
	TICKET_DETAILS_DATA['draft']['clearingDraft'] = true;
	if(editorId != "cnt-reply-body"){
		$("#"+editorId).val("");
	}
	else{
		$("#"+editorId).setCode(TICKET_DETAILS_DATA['draft']['default_reply']);
	}
	TICKET_DETAILS_DATA['draft']['hasChanged'] = false;
	TICKET_DETAILS_DATA['draft']['saved'] = false;
	_clearDraftDom();
}

remove_file_size_alert = function(element){
	var _form = $(element).parents('form');
	$('#file_size_alert_' + _form.data('cntId')).hide();
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
		$element = $('#' + formid + ' textarea').get(0);
		$element.value = $(link).data('replytoHandle');
		$element.value += $element.value.length ? " " : "";
		setCaretToPos($element, $element.value.length);
	} else {
		//For all other reply forms using redactor.
		invokeRedactor(formid+"-body",formid);
		
		if (link && $(link).data('noteType') === 'fwd') {
			$('.forward_email input').trigger('focus');
		} 
		
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
	window.AgentCollisionShow.reply_event();
	activeForm.trigger("visibility")

	//Draft Saving for Reply form
	if (formid == 'cnt-reply') {
		dontSaveDraft = false;
		if (!savingDraft){
			TICKET_DETAILS_DATA['draft']['hasChanged'] = false;
			triggerDraftSaving();
			if (!draftClearedFlag) {
				$("#draft-save").text(TICKET_DETAILS_DATA['draft']['saved_text']);
				$("#reply-draft").show();
				$(".ticket_show #reply-draft").parent().addClass('draft_saved');
			}else{
				$("#reply-draft").hide();
				$(".ticket_show #reply-draft").parent().removeClass('draft_saved');
			}
		}
	} else {
		stopDraftSaving();
	}
}

insertIntoConversation = function(value,element_id){
	var tweet_area = $('#cnt-tweet');
	element_id = element_id || $('#canned_response_show').data('editorId');
	$element = $("#" + element_id);
	if(tweet_area.css("display") == 'block'){
		get_short_url(value, function(bitly){
				insertTextAtCursor( $('#send-tweet-cnt-tweet-body'), bitly || value );
				$('#send-tweet-cnt-tweet-body')
						.trigger("focus")
						.trigger("keydown");
		});         
	}

	$('#canned_responses').modal('hide');

	if($element){
		if(element_id == "send-tweet-cnt-reply-body" || element_id == "send-fb-post-cnt-reply-body" || element_id == "send-mobihelp-chat-cnt-reply-body" || 
				element_id == "send-ecommerce-post-cnt-reply-body" ){
			var textValue = jQuery("<div />").html(value).text();
			$element.focus();
			insertTextAtCursor($element.get(0), textValue);
			$element.keyup(); // to update the SendTweetCounter value
		}
		else{
			$element.data('redactor').insertOnCursorPosition('inserthtml',value);
			$element.getEditor().focus();
		}
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
			//loadRecent();
		}
	});
	return true;
}


showHideToEmailContainer = function(){
	$(".toEmailMoreContainer").toggle();
	if($(".toEmailMoreContainer").css("display") == "inline"){
		$(".toEmailMoreLink").text('');
	}
}

TICKET_DETAILS_DOMREADY = function() {

activeForm = null, savingDraft = false, draftClearedFlag = TICKET_DETAILS_DATA['draft']['cleared_flag'];
$('#ticket_original_request *').css({position: ''}); //Resetting the Position

$('body').on('mouseover.ticket_details', ".ticket_show #draft-save", function() {
	var hasMoment = $(this).attr('data-moment');
	// Checking if moment exists and if the draft has been saved for the current view.
	if(hasMoment && moment){
	  $(this).attr('title', moment(hasMoment).fromNow());
	}
});

$('body').on('mouseover.ticket_details', ".conversation", function() {
	$(this).find('.note-label').remove();
});

// Attach file button click action
$('body').on('click.ticket_details', '.add_attachment', function() {
	$(this).siblings('.original_input').trigger('click');
});

// This has been moved as a on click event directly to the cancel button 
// jQuery('input[type="button"][value="Cancel"]').bind('click', function(){cleardraft();});

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
			$('#show_more').removeClass('loading').addClass('hide');
			$('[rel=activity_container]').prepend(response);
			trigger_event("ticket_show_more",{})
			try {
			freshfonePlayerSettings();
		} catch (e) { console.log("freshfonePlayerSettings not loaded");}
		});
	});
}

$('body').on('click.ticket_details','#checkfreshfoneaudio',function(ev){
		ev.preventDefault();
		window.location.reload(true);
});
// ----- END FOR REVERSE PAGINATION ------ //

changeStatusTo = function(status) {
	$('#helpdesk_ticket_status option').prop('selected', false);
	$('#helpdesk_ticket_status option[value=' + status + ']').prop('selected', true);
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

var scrollToError = function(){
	var errorLabel = $("label[class='error'][style!='display: none;']");
	var elem = errorLabel.parent().children().first();
	setTimeout(function() { $.scrollTo(elem); }, 100 );
}

// For Setting Due-by Time


	$( "#due-date-picker" ).datepicker({
		showOtherMonths: true,
		selectOtherMonths: true,
		changeMonth: true,
		changeYear: true,
		onSelect: function(dateText, inst) {
			selectedDate = new Date(inst.selectedYear, inst.selectedMonth, inst.selectedDay);
			$("#due-date-value").html( moment(selectedDate).format(getDateFormat('moment_date_with_week')) );
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
		var engMoment = moment(_date_time);
		return engMoment.lang("en").format("ddd MMM DD YYYY HH:mm:ss") +" GMT"+engMoment.lang("en").format("Z").replace(":","");         
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

	$(document).on("click.ticket_details", '#ticket_original_request a, .details a', function(ev){
		this.target = "_blank";
	})
	
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
		// get the current selected agent if any
		var select_agent = $('#TicketProperties .default_agent select')[0];
		var prev_val = select_agent.options[select_agent.selectedIndex].value;

		$('#TicketProperties .default_agent')
			.addClass('sloading loading-small loading-right');

		$.ajax({type: 'GET',
			url: prev_val == "" ? '/helpdesk/commons/group_agents/'+this.value : '/helpdesk/commons/group_agents/'+this.value+"?agent="+prev_val,
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
	$("#TicketProperties select.dropdown, #TicketProperties select.dropdown_blank, #TicketProperties select.nested_field").livequery(function(){
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
		var hash_val = []
		TICKET_DETAILS_DATA['tag_list'].each(function(item, i){ hash_val.push({ id: item, text: item }); });

		$(this).select2({
			multiple: true,
			maximumInputLength: 32,
			data: hash_val,
			quietMillis: 500,
			ajax: { 
        url: '/search/autocomplete/tags',
        dataType: 'json',
        data: function (term) {
            return { q: term };
        },
        results: function (data) {
          var results = [];
          jQuery.each(data.results, function(i, item){
          	var result = escapeHtml(item.value);
            results.push({ id: result, text: result });
          });
          return { results: results }

        }
	    },
	    initSelection : function (element, callback) {
	      callback(hash_val);
	    },
	    formatInputTooLong: function () { 
      	return MAX_TAG_LENGTH_MSG; },
		  createSearchChoice:function(term, data) { 
		  	//Check if not already existing & then return
        if ($(data).filter(function() { return this.text.localeCompare(term)===0; }).length===0)
	        return { id: term, text: term };
	    }
		});
	})


	// For Twitter Replybox
	$("body").on("change.ticket_details", '#twitter_handle', function (){
		twitter_handle= $('#twitter_handle').val();
		tweet_type = $('#tkt_tweet_type').val();
		in_reply_to = $('#in_reply_to_handle').val();
		
		istwitter = $('#cnt-reply').data('isTwitter');
		if (!istwitter || in_reply_to == "" || twitter_handle == "" || tweet_type == 'dm')        
			return ;

		$.ajax({   
			type: 'GET',
			url: '/social/twitter/user_following?twitter_handle='+twitter_handle+'&req_twt_id='+in_reply_to,
			contentType: 'application/text',
			success: function(data){ 
				if (data.user_follows == true)
				{
					$('#not_following_message').hide();
				}
				else
				{
					$('#not_following_message').html(data.user_follows)
					$('#not_following_message').show();
				}
			}
		});
	});  
	
	 // For Twitter Replybox
	$("body").on("change.ticket_details", '#tweet_type', function (){
	  var istwitter = $('#cnt-reply').data('isTwitter');
	  
	  if (!istwitter) return ;
	   
	  getTweetTypeAndBind();
	});  

	function getTweetTypeAndBind(){
		var reply_type = $('#tweet_type').val(),
	  		count = (reply_type == 'dm') ? 10000 : 140;
	  
	  bindNobleCount(count);
	}

	function bindNobleCount(max_chars){
	  $('#send-tweet-cnt-reply-body').unbind();
	  
	  $('#send-tweet-cnt-reply-body').NobleCount('#SendTweetCounter', { on_negative : "error", max_chars : max_chars }); 
	  
	  var char_val = $("#SendTweetCounter").text();
	  $('#send-tweet-cnt-reply-body').data("tweet-count", char_val);
	 }


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
		$(this).trigger('cleared.emailField');
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
				trigger_event("activities_toggle",{ current: showing_notes ? 'notes' : 'activities' });
			}, 
			error: function(response) {
				$('#show_more').removeClass('hide');
				_toggle.toggleClass('active disabled');
			}
		})
	});

	$('body').on('click.ticket_details', '[rel=activity_container] .minimizable', function(ev){
		if ($(ev.target).is('a')) return;
		if(($(this).find(".edit_helpdesk_note").length == 0) || ($(this).find(".edit_helpdesk_note").is(":hidden"))){
			$(this).toggleClass('minimized');
		}
	});

	$('body').on('click.ticket_details', '.collision_refresh', function(ev) {
		window.location = TICKET_DETAILS_DATA['ticket_path'];
	});

	$('body').on('click.ticket_details', ".conversation_thread .request_panel form .submit_btn", function(ev) {
		ev.preventDefault();
        if(window.replySubscription)
        {
          window.replySubscription.cancel();
        }
        window.FreshdeskNode.getValue('faye_realtime').faye_subscriptions.splice(window.FreshdeskNode.getValue('faye_realtime').faye_subscriptions.indexOf(window.relySubscription), 1);
		$(this).parents('form').trigger('submit');
	});

	$('body').on('click.ticket_details', ".conversation_thread .request_panel form .cancel_btn", function(ev) {
		ev.preventDefault();
		var btn = $(this);
		if(TICKET_DETAILS_DATA['draft']['saved'] && btn.data('cntId') && btn.data('cntId') == "cnt-reply"){
			if(!confirm(TICKET_DETAILS_DATA['draft']['clear_text'])){
				window.AgentCollisionShow.reply_event();
				return false; 
			} 
        }
		remove_file_size_alert(btn)
		$('#' + btn.data('cntId')).hide().trigger('visibility');
		if (btn.data('showPseudoReply')) 
			$('#TicketPseudoReply').show();

		var _form = $('#' + btn.data('cntId') + " form");

		if (btn.data('clearDraft')) {
			clearSavedDraft(btn.data('editorId'));
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

		if (btn.data('cntId') == "cnt-reply") {
			$('#cnt-reply-body').val(TICKET_DETAILS_DATA['draft']['default_reply']);
		}
		
		if(_form.attr('rel') == 'tweet_form'){
			getTweetTypeAndBind();
		}

		if (_form.attr('rel') == 'forward_form')  {
			//Remove To Address
			_form.find('.forward_email li.choice').remove();
		}
		$('#response_added_alert').remove();
	});

	// More Event bindings for Draft Saving
	$('body').on("added.Autocompleter removed.Autocompleter cleared.emailField", function(ev) {
		if (typeof(TICKET_DETAILS_DATA) !== 'undefined') {
			if (typeof(TICKET_DETAILS_DATA['draft']['clearingDraft']) === 'undefined' || !TICKET_DETAILS_DATA['draft']['clearingDraft']) {
				isDirty=true;
				TICKET_DETAILS_DATA['draft']['hasChanged'] = true;
			} else {
				TICKET_DETAILS_DATA['draft']['clearingDraft'] = false;
			}
		} else {
			isDirty=true;
		}
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

			if (_form.attr('rel') == 'forward_form' || _form.attr('rel') == 'reply_to_forward_form')  {
				//Check for To Addresses.              
				if (_form.find('input[name="helpdesk_note[to_emails][]"]').length == 0 )
				{
					alert('No email addresses found');
					return false;
				}
			}
			if (_form.find('input[name="helpdesk_note[to_emails][]"]').length >= MAX_EMAILS) {
				alert('You can add upto ' + MAX_EMAILS + ' TO emails');
				return false;
			}

			if (_form.find('input[name="helpdesk_note[cc_emails][]"]').length >= MAX_EMAILS) {
				alert('You can add upto ' + MAX_EMAILS + ' CC emails');
				return false;
			}

			if (_form.find('input[name="helpdesk_note[bcc_emails][]"]').length >= MAX_EMAILS) {
				alert('You can add upto ' + MAX_EMAILS + ' BCC emails');
				return false;
			}

			_form.find('input[type=submit]').prop('disabled', true);

			var statusChangeField = $('#send_and_set');
			if(statusChangeField.data('val') != undefined && statusChangeField.data('val') != "") {

				var propertiesForm = $("#custom_ticket_form");
				if(propertiesForm.valid()) {

					if($.browser.msie) {
						if(eligibleForReply(_form)){
							handleIEReply(_form);
							submitTicketProperties();
							return true;
						}
						changeStatusTo(currentStatus);
						statusChangeField.data('val', '');
						return false;
					} else {
						ev.preventDefault();
						blockConversationForm(_form);
						submitNewConversation(_form, ev, submitTicketProperties);
		      }
				} else {
					ev.preventDefault();
					scrollToError();
				}
			} else {
				if($.browser.msie) {
					if(eligibleForReply(_form)){
						handleIEReply(_form);
						return true;
					}
					return false;
				} else {
					ev.preventDefault();
					blockConversationForm(_form);
					submitNewConversation(_form, ev, afterTktPropertiesUpdate);
				}
			}
			
		} else {
			_form.find('input[type=submit]').prop('disabled', false);
		}
	});


    $('body').on('submit.ticket_details', '#custom_ticket_form', function(ev) {
		ev.preventDefault(); 
		ev.stopPropagation();
		var tkt_form = $('#custom_ticket_form');
		if (tkt_form.valid()) {
			submitTicketProperties();
		} else {
			scrollToError();
		}
			
	});

	var handleIEReply = function(_form) {
		seperateQuoteText(_form);
		if (_form.data('cntId') && _form.data('cntId') == 'cnt-reply') {
			stopDraftSaving();
		}
	}

	var eligibleForReply = function(_form) {
		var replyStatus;
		$('#response_added_alert').remove();
		if(_form.data('cntId') == 'cnt-fwd' || jQuery(_form).find('#helpdesk_note_private[type=checkbox]').is(':checked')){
			return true;
		}
		$.ajax({
			type: 'GET',
			url: "/helpdesk/tickets/"+TICKET_DETAILS_DATA['displayId']+"/conversations/traffic_cop",
			dataType: 'script',
			async: false,
			data: { last_note_id: $('.last_note_id').val(), since_id: TICKET_DETAILS_DATA['last_note_id'] },
			success: function(data) {
				if($('#response_added_alert').length > 0){
					replyStatus = false;
				} else {
					replyStatus = true;
				}
			}
		});
		return replyStatus;
	}

	var blockConversationForm = function(_form) {
		var panel = _form.data('panel');
		if (panel) {
			var form_el = $('#' + panel);
			form_el = _form.data("form") ? form_el.find(".commentbox") : form_el;
			form_el.block({
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
	}

	var submitNewConversation = function(_form, ev, callback) {
		
		callback = callback || function(){};

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
				if (_form.data('cntId') && _form.data('cntId') == 'cnt-reply') {
					stopDraftSaving();				
				}

			},
			success: function(response, statusCode, xhr) {
				var statusChangeField = $('#send_and_set');
								
				if($('#response_added_alert').length > 0 && _form.parents('#all_notes').length < 1){
					if (_form.data('panel')) {
						$('#' + _form.data('panel')).unblock();
					}
					if (_form.data('cntId') && _form.data('cntId') == 'cnt-reply') {
						triggerDraftSaving();
					}

					_form.trigger('focusin.keyboard_shortcuts');

					if(statusChangeField.data('val') != undefined && statusChangeField.data('val') != ""){
						changeStatusTo(currentStatus);
						statusChangeField.data('val','');
						$('.ticket_details #helpdesk_ticket_status').data('updated',false);
					}
				}else if($.trim(response).length){
					if (_form.data('panel')) {

						if(_form.data("form")){
							var $form = $('#' + _form.data('panel')),
								form_container = $form.find(".commentbox");

							form_container.unblock();
						} else {
							$('#' + _form.data('panel')).unblock();
						}

						$('#' + _form.data('panel')).hide();
						$('#' + _form.data('panel')).trigger('visibility');
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
						submit_btn.find('[rel=text]').text(submit_btn.data('defaultText'));
					}

					//Enabling original attachments
					_form.find('.item[rel=original_attachment]').show();
					_form.find('input[rel=original_attachment]').prop('disabled', false);

					try {
						if (_form.data('cntId') && _form.data('cntId') == 'cnt-reply') {
							stopDraftSaving();
							$('#cnt-reply-body').val(TICKET_DETAILS_DATA['draft']['default_reply']);
							_clearDraftDom();
						}	
					} catch(e) {}
					// The above block has been added so that Redactor errors do not restrict further flow.
					

					_form.find('[rel=ajax_params]').remove();
						
					_form.find('input[type=submit]').prop('disabled', false);
					if (_form.data('showPseudoReply')) {
						$('#TicketPseudoReply').show();
						callback();
					}
				} else {
					_form.find('input[type=submit]').prop('disabled', false);

					if (_form.data('panel')) {
						$('#' + _form.data('panel')).unblock();
					}
					$('#file_size_alert_' + _form.data('cntId')).show();

					if (_form.data('cntId') && _form.data('cntId') == 'cnt-reply') {
						triggerDraftSaving();
					}
				}
				
				if(_form.attr('rel') == 'tweet_form'){
					getTweetTypeAndBind();
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
	}


	var submitTicketProperties = function(callback) {
		
		var tkt_form = $('#custom_ticket_form');
		var submit = $('#custom_ticket_form .btn-primary');
		submit.button('loading');
		submit.attr('disabled','disabled');

		callback = callback || function(){};

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

				callback();

				if(response.redirect)
				{
					$('[rel=link_ticket_list]').click();
				} else {
					var statusChangeField = $('#send_and_set');
					if(statusChangeField.length) {
						if(statusChangeField.data('val') != '') {
							refreshStatusBox();
							if(statusChangeField.data('val') == TICKET_CONSTANTS.statuses.resolved || statusChangeField.data('val') == TICKET_CONSTANTS.statuses.closed) {
								$('[rel=link_ticket_list]').click();
							}
							statusChangeField.data('val', '');
						}
					}
					afterTktPropertiesUpdate();
				}

				

			},
			error: function(jqXHR, textStatus, errorThrown) {
				submit.text(submit.data('default-text')).prop('disabled',false);
			}
		});
	}

	var afterTktPropertiesUpdate = function() {
		var postProcess = false,
			tkt_form = $('#custom_ticket_form');
		//Priority, Status, Group, Type, Product
		var fields_to_check = ['priority', 'status', 'group_id', 'ticket_type', 'product', 'source'];
		for(i in fields_to_check) {
			if (typeof(fields_to_check[i]) == 'string' && $('.ticket_details #helpdesk_ticket_' + fields_to_check[i]).data('updated')) {
				postProcess = true;	
				break;
			}
		}
		var ticket_fields = tkt_form.find(':input');
		var data_hash = {};
		ticket_fields.each(function() {
			if($(this).data().updated)
			{	
				var field_name = $(this).attr('name');
				data_hash[field_name] = {
					value: $(this).val(), 
					datatype: $(this).get(0).tagName.toLowerCase(),
					type: field_name.match(/\[.*?\]/)[0] == "[custom_field]" ? "custom_field" : "default" ,
					required: $(this).hasClass('required')
				};
			}
		});
		if (!$.isEmptyObject(data_hash)){
			trigger_event("ticket_fields_updated",data_hash);
		}
		ticket_fields.data('updated', false);

		$("#send_and_set").removeData("val");
		$("#send_and_set").prop('disabled', true);

		if(postProcess) {
			var source_badge = $('.ticket_details .source-badge-wrap .source')
			var is_refreshed = true;
			if(source_badge.hasClass("collision_refresh")){
				is_refreshed = false;
			}
			source_badge
					.attr('class','')
					.addClass('source ')
					.addClass('priority_color_' + $('.ticket_details #helpdesk_ticket_priority').val())
					.addClass('status_' + $('.ticket_details #helpdesk_ticket_status').val());
			if(!is_refreshed){
				source_badge.addClass('collision_refresh');
			}

			$('.ticket_details .source-badge-wrap .source span')
					.attr('class','')
					.addClass('source_' + $('.ticket_details #helpdesk_ticket_source').val());
			refreshStatusBox();
		}
	}

	window.closeCurrentTicket = function (ev) {
		changeStatusTo(TICKET_CONSTANTS.statuses.closed);
		if($('#custom_ticket_form').valid())
		{
			var action_attr = $('#custom_ticket_form').attr("action"),
				isSilentClose = ev.shiftKey || false,
				disable_notification = isSilentClose ? "?disable_notification=" + isSilentClose + "&redirect=true" : "?redirect=true";

			$('#custom_ticket_form').attr("action", action_attr + disable_notification);
			$('#custom_ticket_form').submit();
		} else {
			scrollToError();
		}
	}

	var openConversation = function(){ 
		var key = window.location.hash; 
		switch (key){
			case "#reply":
			    $('#ReplyButton').trigger('click');
			    break;
			case "#forward":
			    $('#FwdButton').trigger('click')
			    break;
			case "#add_note":
			    $('#noteButton').trigger('click')
			    break;
		}
	}    

	setTimeout(openConversation, 200);

	$(document).on('click.ticket_details','.conversation .dialog-btn',function(){
		var id = jQuery('.conversation_thread form:visible').attr('id')
		jQuery( "#" + id + " ul.dropdown-menu").focus();
	})

	$('body').on('click.ticket_details', '[rel=TicketReplyPlaceholder]', function(ev) {
		ev.preventDefault();
		$(this).hide();
		$('#ReplyButton').click();
	});
	
	// Facebook event binding
	
	$('body').on('click.ticket_details', ".reply-facebook", function(event){
	    $('#ReplyButton').trigger('click');
	    note_id = $(this).data('noteId');
	    requester_name = $(this).data('note-requester-name');
	    $("#fb_form_title").html(requester_name);
	    $("#parent_post_id").val(note_id);
	  });
	
	$('body').on('click.ticket_details', "#facebook-cancel-reply", function(event){
			requester_name = $("#ticket_requester_name").val();
	    $("#fb_form_title").html(requester_name);
	    $('#parent_post_id').val('')
	  });
	
	
	//For showing canned response and solutions

	$('body').on('click.ticket_details', 'a[rel="ticket_canned_response"]', function(ev){
		ev.preventDefault();
		$('#canned_response_show').data('editorId', $(this).data('editorId'));
		var editorId = $('#canned_response_show').data('editorId');
		if (editorId != 'send-tweet-cnt-reply-body' && editorId != 'send-fb-post-cnt-reply-body' && editorId != 'send-mobihelp-chat-cnt-reply-body' &&
			editorId != 'send-ecommerce-post-cnt-reply-body' ){
			$('#'+editorId).data('redactor').saveSelection();
		}
		$('#canned_response_show').trigger('click');
	});

	$('body').on('click.ticket_details', 'a[rel="ticket_solutions"]', function(ev){
		ev.preventDefault();
		$('#suggested_solutions_show').data('editorId', $(this).data('editorId'));
		var editorId = $('#suggested_solutions_show').data('editorId');
		if (editorId != 'send-tweet-cnt-reply-body' && editorId != 'send-fb-post-cnt-reply-body' && editorId != 'send-mobihelp-chat-cnt-reply-body' && 
			editorId != 'send-ecommerce-post-cnt-reply-body'){
			$('#'+editorId).data('redactor').saveSelection();
		}
		$('#suggested_solutions_show').trigger('click');
	});

	//End

	//Toggling Note visiblity
	$('body').on('change.ticket_details', '#toggle-note-visibility input[type=checkbox]', function(ev){
		var submit_btn = $(this).parents('form').find('.submit_btn');
		if($(this).is(':checked')) {
			submit_btn.find('[rel=text]').text(submit_btn.data('defaultText'));
		} else {
			submit_btn.find('[rel=text]').text(submit_btn.data('publicText'));
		}
	});

	$('body').on('click.ticket_details', '[rel=close_ticket_btn]', function(ev){
		closeCurrentTicket(ev);
		return false;
	});

    $('body').on('click.ticket_details', '[rel=custom-reply-status]', function(ev){
      ev.preventDefault();
      ev.stopPropagation();
      currentStatus = $('#helpdesk_ticket_status').val();
      jQuery('body').click();

      var new_status	= $(this).data('statusVal'),
      		noteForm	= $(this).parents('form'); 
      changeStatusTo(new_status);
      handleSendAndSet(new_status);
      $('#send_and_set').data('val', ($(this).data('statusVal')));
      noteForm.trigger('submit');
    });

  function handleSendAndSet(statusVal){
  	var resolved_or_closed = [TICKET_CONSTANTS.statuses.resolved, TICKET_CONSTANTS.statuses.closed].include(statusVal);
  	$("#send_and_set").prop('disabled', !resolved_or_closed);
  }

	// Scripts for ToDo List
	$('body').on('keydown.ticket_details', '.addReminder textarea', function(ev) {
		if(ev.keyCode == 13){
			ev.preventDefault();
			if(trim($(this).val()) != '') $(this).parents('form').submit();
		}
	});

	$('body').on('click', '.reminder_check', function () {
		$(this).parent().addClass('disabled');
	});

	//Binding the Reply/Forward/Add Note buttons
	$('body').on('click.ticket_details', '[rel=note-button]', function(ev) {
		if (!$(this).parent().parent().hasClass('dropdown-menu')) {
			ev.preventDefault();
			ev.stopPropagation();
		}
		if($(this).data('note-type') === 'note'){
			addNoteAgents();	
		}
		swapEmailNote('cnt-' + $(this).data('note-type'), this);
	});

	$('body').on('click.ticket_details', '[rel=review-button]','[id=ReviewButton]', function(ev) {
		if(confirm("Do you want to send request for App review?")) {
			$("#HelpdeskReviewNotes").submit();
		}
		ev.preventDefault();
		ev.stopPropagation();
	});
	//ScrollTo the latest conversation

	if (updateShowMore()) updatePagination();

	//Previous Next Buttons request
	$.getScript("/helpdesk/tickets/" + TICKET_DETAILS_DATA['displayId'] + "/prevnext");

	$('#twitter_handle').change();

	// MOVE TO !PATTERN
	$('body').on('change.pattern', '.selected_to_yellow [type=radio], .selected_to_yellow [type=checkbox]', function(ev) {
		$(this).parents('.selected_to_yellow').find('.stripe-select').removeClass('stripe-select');
		$(this).parents('td').first().toggleClass('stripe-select', $(this).prop('checked'));
	});

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
			$.each(messages,function(str) {
				msg += str + "\n";
			});

			e = e || window.event;
			if (e) {
				e.returnValue = msg;
			}

			return msg;
		}
	});
	var findWhereToScroll = function() {
		var element = $(window.location.hash);
		if (element.length) {
			$.scrollTo(element);
		} else {
			//If it is a note, expand all notes
			if (window.location.hash.substr(0,5) == '#note') {
				$.scrollTo('#show_more');
			} else if(TICKET_DETAILS_DATA['scroll_to_last']) {
				$.scrollTo('[rel=activity_container] .conversation:last');
			}
		}
	}

	setTimeout(findWhereToScroll, 200);

	(function(){
		var tkt_prop = $('#TicketProperties .content');
		tkt_prop.append("<div class='sloading loading-small loading-block'></div>");
        tkt_prop.load(tkt_prop.data('remoteUrl'), function(){
            tkt_prop.data('remoteUrl', false);

			$('body').on('change.ticket_details', '#custom_ticket_form', function(ev) {
				
				if (!dontAjaxUpdate) 
				{
					TICKET_DETAILS_DATA['updating_properties'] = true;
					$(ev.target).data('updated', true);
					$('#custom_ticket_form').data('updated', true);
				}
				dontAjaxUpdate = false;
			} );
			trigger_event("sidebar_loaded",{name: "ticket_properties", dom_id: "#TicketProperties"});
        });	
	})()
	
	trigger_event("ticket_view_loaded",{});
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

    jQuery(document).off(".ticket_details")
    trigger_event("ticket_view_unloaded",{});

	var custom_events = [
		"time_entry_deleted",
		"time_entry_created",
		"time_entry_started",
		"time_entry_stopped",
		"time_entry_updated",
		"todo_created",
		"todo_completed",
		"note_created",
		"note_updated",
		"ticket_fields_updated",
		"scenario_executed",
		"ticket_show_more",
		"activities_toggle",
		"ticket_view_loaded",
		"ticket_view_unloaded",
		"sidebar_loaded",
		"watcher_added",
		"watcher_removed"
	];

	for(var i=0; i<custom_events.length ; i++){
		jQuery(document).off(custom_events[i]);
	}


};

jQuery('.freshdesk_quote .q-marker').live('click', function(){
  var _container = jQuery(this).parents('.details');
  var _fd_quote = jQuery(this).parents('.freshdesk_quote')
  if (_fd_quote.data('remoteQuote')){
    var _note_id = _container.data('note-id');
    var _messageDiv = _container.find('div:first');
    var options = {"force_quote": true};
    jQuery.ajax({
      url: '/helpdesk/tickets/'+TICKET_DETAILS_DATA["displayId"]+'/conversations/full_text',
      data: { id: _note_id },
      success: function(response){
        if(response!=""){
          _messageDiv.html(response);

          quote_text(_messageDiv, options);
        }
        else {
          _container.find('div.freshdesk_quote').remove();
        }
      }
    });
  }
});

})(jQuery);
