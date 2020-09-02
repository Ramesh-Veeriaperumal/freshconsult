/*jslint browser: true, devel: true */
/*global  App */

window.App = window.App || {};
window.App.Tickets = window.App.Tickets || {};


(function ($) {

var activeForm, savingDraft, draftClearedFlag, draftSavedTime,dontSaveDraft, replyEditor, draftInterval, currentStatus;
var MAX_EMAILS = 50;
// ----- SAVING REPLIES AS DRAFTS -------- //
var save_draft = function(content, cc_email_list, bcc_email_list, inlineAttachmentIds) {
	if ($.trim(content) != '') {
		$(".ticket_show #reply-draft").show().addClass('saving');
		// $(".ticket_show #reply-draft").parent().addClass('draft_saved');

		$(".ticket_show #draft-save").text(TICKET_DETAILS_DATA['draft']['saving_text']);
		savingDraft = true;
		$.ajax({
			url: TICKET_DETAILS_DATA['draft']['save_path'],
			type: 'POST',
			data: {draft_data: content,
			       draft_cc: cc_email_list,
			       draft_bcc: bcc_email_list,
			       inline_attachment_ids: inlineAttachmentIds
			   },
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

var autosaveDraft = function() {
	if(dontSaveDraft == 0 && TICKET_DETAILS_DATA['draft']['hasChanged']) {
		var content = $('#cnt-reply-body').getCode();
		var inlineAttachmentIds = [];
		$('#cnt-reply-body').parents('form').find('.inline-attachment-input').each(function(){
			inlineAttachmentIds.push($(this).val());
		})

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
			save_draft(content, cc_email_list, bcc_email_list, inlineAttachmentIds);

		// When the reply draft is saved, turn the formChanged flag off on the reply
		jQuery('#cnt-reply-body').parents('form').data('formChanged',false);
	}

	TICKET_DETAILS_DATA['draft']['hasChanged'] = false;
}

var triggerDraftSaving = function() {
	dontSaveDraft = 0;
	draftInterval = setInterval(autosaveDraft, 30000);
}

var stopDraftSaving = function() {
	dontSaveDraft = 1;
	clearInterval(draftInterval);
}

var _clearDraftDom = function() {
	$(".ticket_show #reply-draft").hide();
	$(".ticket_show #reply-draft").parent().removeClass('draft_saved');
	draftClearedFlag = true;
}
var clearSavedDraft = function(editorId){
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
	resetInlineAttachments($("#"+editorId).parents("form"));
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
	if(!Helpdesk.MultipleFileUpload.addToRply.replyTrigger) {
		$.scrollTo('#'+formid, {offset: 100});
	}
	if (activeForm.data('type') == 'textarea') {
		//For Facebook and Twitter Reply forms.
		$element = $('#' + formid + ' textarea').get(0);
		//changes done as part of linked tickets
		if($(link).data('replytoHandle')) {
			if($element.value.trim() !== $(link).data('replytoHandle')) {
				if ($(link).data('replytoHandle').trim() == $(link).data('user').trim()) {
					$(link).data('user', '');
				}
				$element.value = $(link).data('replytoHandle') + $(link).data('user');
				$($element).trigger('keydown');
			}
		}
		//$element.value += $element.value.length ? " " : "";
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
				// $(".ticket_show #reply-draft").parent().addClass('draft_saved');
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
		if(element_id == "send-tweet-cnt-reply-body" || element_id == "send-fb-post-cnt-reply-body" || element_id == "send-ecommerce-post-cnt-reply-body" ){
			var textValue = jQuery("<div />").html(value).text().trim();
			$element.focus();
			insertTextAtCursor($element.get(0), textValue);
			$element.keyup(); // to update the SendTweetCounter value
			$element.trigger('change'); // to set formChanged flag
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
// $('#ticket_original_request *').css({position: ''}); //Resetting the Position

$('body').on("click.conversation_action", '.conv-action-icon', function(ev){
		var fetchedId = ev.target.id;
	    //slicing 'conv-action-' prefix from conv-action-icon's id value
	    var selectedId = fetchedId.slice(12);
	    jQuery('#'+selectedId).show().trigger('afterShow');
	    invokeRedactor(selectedId+'-body'); 

	    // start-----hack for hiding multiple instance of fwd edit in public note-----
		var noteIdNo = ev.target.getAttribute("noteId");
		var typeOfBtn = selectedId.substring(0, 5);
			if(typeOfBtn === "cnt-f")	//cnt-fwd-{noteId}
					{jQuery("#edit-"+noteIdNo).hide();}
			if(typeOfBtn === "edit-")	//edit-{noteId}
					{jQuery("#cnt-fwd-"+noteIdNo).hide();}
	    // end-------hack for hiding multiple instance of fwd edit in public note-----
	});

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
var paginationScroll = function(){
	var element = $("[data-activity-id ='"+TICKET_DETAILS_DATA['last_activity_batch']+"']");
	if(element){
		$.scrollTo(element,{offset: $(window).height()-jQuery('#sticky_header').outerHeight(true)});
	}
}

var updateShowMore = function() {

	//Checking if it is Notes (true) or Activities (false)
	var showing_notes = $('#all_notes').length > 0;
	var total_count, loaded_items, show_more;
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
		show_more = true;
	} else {
		$('#show_more').addClass('hide');
		show_more =  false;
	}
	if(!showing_notes){
		paginationScroll();
	}
	return show_more;
}

var fetchMoreAndRender = function(ev, cb) {
	ev.preventDefault();

	var showing_notes = $('#all_notes').length > 0;
	$('#show_more').addClass('loading');
	
	var href;
	if (showing_notes)
		href = TICKET_DETAILS_DATA['notes_pagination_url'] + 'before_id=' + TICKET_DETAILS_DATA['first_note_id'];
	else
		href = TICKET_DETAILS_DATA['activities_pagination_url'] + 'before_id=' + TICKET_DETAILS_DATA['first_activity'] + '&limit=' +  TICKET_DETAILS_DATA['pagination_limit'];

	$.get(href, function(response) {
		if(response.trim()!=''){
			TICKET_DETAILS_DATA['first_activity'] = null;
			TICKET_DETAILS_DATA['first_note_id'] = null;
		}
		TICKET_DETAILS_DATA['last_activity_batch'] = null;
		$('#show_more').removeClass('loading').addClass('hide');
		$('[rel=activity_container]').prepend(response);
		updateShowMore();
		trigger_event("ticket_show_more",{})

		try {
			// retries remaining annotations after more notes are loaded
			if(!!App && !!App.CollaborationModel && !!App.CollaborationModel.restoreAnnotations) {
				App.CollaborationModel.restoreAnnotations();
			}
		}
		catch(e) {
			console.log("No way to restore Collaboration's annotations.");
		}

		if(typeof cb === "function") {cb(response);}
	});
}

window.App.fetchMoreAndRender = fetchMoreAndRender;

var updatePagination = function() {
	//Unbinding the previous handler:
	$('#show_more').off('click.ticket_details');
	$('#show_more').on('click.ticket_details', fetchMoreAndRender);
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

refreshRequesterWidget = function(){
	$.ajax({
		url: TICKET_DETAILS_DATA['refresh_requester_widget'],
		success: function(response){
		}
	})
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
		jQuery('.requester-info-sprite').parents('.tkt-tabs').hide();
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
	//code added for shared-ownership changes
	$('body').on('change.ticket_details' ,'#helpdesk_ticket_status', function(event){ 

		var _this = $(this);
		var previous =  _this.data("previous");
		//in case of deleted status, manually pass the condition for api trigger
		if(previous !== "" && !previous){
			previous = true;
		}
		_this.data("previous", _this.val());
		var select_group = jQuery('#TicketProperties .default_internal_group select')[0];
		var prev_val = ""
		if(select_group){
      		prev_val = select_group.options[select_group.selectedIndex].value;
		}

		if(previous && select_group){
			$('#TicketProperties .default_internal_group').addClass('sloading loading-small loading-right');

		    $.ajax({type: "GET",
		      	url: prev_val == "" ? "/helpdesk/commons/status_groups?status_id="+$("#helpdesk_ticket_status").val() : "/helpdesk/commons/status_groups?status_id="+$("#helpdesk_ticket_status").val()+"&group_id="+prev_val,
		      	contentType: "application/text",
		      	success: function(data){
		    		$('#helpdesk_ticket_internal_group_id').html(data).trigger('change');
		        	$('#TicketProperties .default_internal_group').removeClass('sloading loading-small loading-right');
		      	}
		    });
		}
	});
	$('body').on("change.ticket_details", '#helpdesk_ticket_internal_group_id', function(e){
	    $('#TicketProperties .default_internal_agent').addClass('sloading loading-small loading-right');
	    var select_group = jQuery('#TicketProperties .default_internal_agent select')[0];
      	var prev_val = select_group.options[select_group.selectedIndex].value;
		if(this.value){
			$.ajax({
		       	type: 'GET',
		      	url:  prev_val == "" ? '/helpdesk/commons/group_agents/'+this.value : '/helpdesk/commons/group_agents/'+this.value+"?agent="+prev_val,
		      	contentType: 'application/text',
		      	success: function(data){
		        	$('#helpdesk_ticket_internal_agent_id').html(data).trigger('change');
		        	$('#TicketProperties .default_internal_agent').removeClass('sloading loading-small loading-right');
		      	}
		    });
		}else{
      		$('#helpdesk_ticket_internal_agent_id').html("<option value=''>...</option>").trigger('change');
			$('#TicketProperties .default_internal_agent').removeClass('sloading loading-small loading-right');
		}  
	});

	$('body').on("click.ticket_details", '.broadcast_message_box a:not("#FwdButton, .q-marker")', function(ev){
		this.attr('target', '_blank');
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
			minimumInputLength: 2,
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
	  		count = (reply_type == 'dm') ? 10000 : 280;

	  bindNobleCount(count);
	}

	function bindNobleCount(max_chars){
	  $('#send-tweet-cnt-reply-body').unbind();

	  $('#send-tweet-cnt-reply-body').NobleCount('#SendTweetCounter', { on_negative : "error", max_chars : max_chars });

	  var char_val = $("#SendTweetCounter").text();
	  $('#send-tweet-cnt-reply-body').data("tweet-count", char_val);
	 }


	//End of Twitter Replybox JS

	//For Facebook DM Replybox

	function bindFacebookDMCount() {
	  $('#send-fb-post-cnt-reply-body').NobleCount('#SendReplyCounter', { on_negative : "error", max_chars : 640, on_update: updateCount });
		updateCount();
	}

	function updateCount() {
	  var char_val = $("#SendReplyCounter").text();
	  $('#send-fb-post-cnt-reply-body').data("reply-count", char_val);
	}


	// End of Facebook DM Replybox


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
	$('#activity_toggle').prop('checked', false);
	$('body').on('click.ticket_details', '#activity_toggle', function(ev) {
		var _toggle = $(this);

		if (_toggle.hasClass('disabled')) {
			_toggle.toggleClass('active');
			return false;
		}
		_toggle.addClass('disabled')
		var showing_notes = $('#all_notes').length > 0;
		var url = showing_notes ? TICKET_DETAILS_DATA['activities_pagination_url']  + 'limit=' + TICKET_DETAILS_DATA['pagination_limit'] : TICKET_DETAILS_DATA['notes_pagination_url'];
		if (showing_notes) {
			TICKET_DETAILS_DATA['first_activity'] = null;
			TICKET_DETAILS_DATA['loaded_activities'] = 0;
		} else {
			TICKET_DETAILS_DATA['first_note_id'] = null;
			TICKET_DETAILS_DATA['total_notes'] = 0;
		}

		$('#show_more').data('next-page',null);  //Resetting
		$.ajax({
			url: url,
			success: function(response) {
				if(response.trim()!=''){
					$('[rel=activity_container]').replaceWith(response);
					$('#show_more').data('next-page',null);  //Resetting
					if (updateShowMore()) updatePagination();
					trigger_event("activities_toggle",{ current: showing_notes ? 'notes' : 'activities' });
					var _shortcut = ' ( ' + _toggle.data('keybinding') + ' )';
					if(showing_notes){
						$("#original_request .commentbox").addClass('minimized');
						if(_toggle.data('hide-title'))
						_toggle.attr('title',_toggle.data('hide-title')+_shortcut);
					}
					else{
						if(TICKET_DETAILS_DATA['scroll_to_last']) {
							$.scrollTo('[rel=activity_container] .conversation:last');
						}
						else{
							$.scrollTo($('body'));
						}
						$("#original_request .commentbox").removeClass('minimizable minimized');
						if(_toggle.data('show-title'))
						_toggle.attr('title',_toggle.data('show-title')+_shortcut);
					}
					_toggle.removeClass('loading_activities disabled');
				}
				else{
					_toggle.removeClass('loading_activities disabled active');
				}
			}, 
			error: function(response) {
				$('#show_more').removeClass('hide');
				_toggle.toggleClass('active disabled');
			}
		})
	});

	$('body').on('click.ticket_details', '.conversation_thread .minimized ', function(ev){
		if ($(ev.target).is('a')) return;
		$(this).toggleClass('minimized minimizable');
	});

	$('body').on('click.ticket_details', '.conversation_thread .minimizable .author-mail-detail, .conversation_thread .minimizable .subject', function(ev){
		if ($(ev.target).is('a')) return;
		var minimizable_wrap = $(this).closest('.minimizable');
		if((minimizable_wrap.find(".edit_helpdesk_note").length == 0) || (minimizable_wrap.find(".edit_helpdesk_note").is(":hidden"))){
			minimizable_wrap.toggleClass('minimized minimizable');
		}
	});

	$('body').on('click.ticket_details', '.collision_refresh', function(ev) {
		pjaxify(TICKET_DETAILS_DATA['ticket_path'])
	});

	$('body').on('click.ticket_details', ".conversation_thread .request_panel form .submit_btn", function(ev) {
		ev.preventDefault();
        if(window.replySubscription)
        {
          window.replySubscription.cancel();
        }
		$(this).parents('form').trigger('submit');
	});

	$('body').on('click.ticket_details', ".conversation_thread .request_panel form .cancel_btn", function(ev) {
		ev.preventDefault();
		var btn = $(this);
		if(TICKET_DETAILS_DATA['draft']['saved'] && btn.data('cntId') && btn.data('cntId') == "cnt-reply"){
			if(!confirm(TICKET_DETAILS_DATA['draft']['clear_text'])){
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
			$('#selectAgentsOptions').select2('data',[]);
			var default_agent_present = $('.email_container.add_select2_custom').data('default-agent');
			var default_agent_option = $('.email_container.add_select2_custom').data('default-agent-disp');
			if ( default_agent_present){
				$('#selectAgentsOptions').val(default_agent_present).trigger('change');
			}

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

		// Remove formChanged field in the form
		_form.data("formChanged",false);
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

			// // Attachment Missing Check
			// if(_form[0] && _form[0]['helpdesk_note[note_body_attributes][body_html]']){
			// 	var replyHtml = _form[0]['helpdesk_note[note_body_attributes][body_html]'].value || "";
			// 	var replyText = replyHtml.split('<div class="freshdesk_quote">')[0];

			// 	// Convert the HTML tag to a text string first
			// 	var temp = document.createElement('DIV');
			// 	temp.innerHTML = replyText;
			// 	replyText = temp.innerText;
				
			// 	if(replyText.toLowerCase().indexOf('attach')>-1){
			// 		var hasAttachments = false;

			// 		var note = _form.serializeObject().helpdesk_note || {};
			// 		var prevAttachments = (note.attachments && note.attachments.length) || 0;
			// 		attachments = jQuery('input[name="helpdesk_note[attachments][][resource]"]:not([rel="original_attachment"])');
			// 		currAttachments = (attachments && attachments[0] && attachments[0].files && attachments[0].files.length) || 0;

			// 	  if(!(currAttachments + prevAttachments)){
			// 	    var missed_attachment_text = TICKET_DETAILS_DATA.attachment_missing_alert;
			// 	    if(!confirm(missed_attachment_text)){
			// 	      return false;
			// 	    }
			// 	  }
			// 	}
			// }
      

			_form.find('input[type=submit]').prop('disabled', true);

			var statusChangeField = $('#send_and_set');
			if(statusChangeField.data('val') != undefined && statusChangeField.data('val') != "") {

				var propertiesForm = $("#custom_ticket_form");
				if(propertiesForm.valid()) {

					if($.browser.msie || $.browser.msedge) {
						if(eligibleForReply(_form)){ 	//if no response added returns true
							handleIEReply(_form);		//stop saving draft if reply
							submitTicketProperties();	// Load button submit ticket prop do callbacks
							removeFormChangedFlag();	// flag reset on submit
							return true;
						}
						changeStatusTo(currentStatus);		//change new status and trigger change
						statusChangeField.data('val', '');		//send and set field data 
						return false;
					} 
					else {
						ev.preventDefault();
						blockConversationForm(_form);	// grey out the form
						if(!isFormLocked(_form)) {		// is form submitting
							lockForm(_form);			// set form submitting
							if (TICKET_DETAILS_DATA['new_send_and_set']){
								send_and_set_a(_form, ev);
							}
							else{
								submitNewConversation(_form, ev, submitTicketProperties);	
							}
						} else {
							//Repeated submission, do something
							console.log('Duplicate Request Blocked');
						}
		      		}
				} 
				else {		// if ticket properties validation fails
					ev.preventDefault();
					scrollToError();
				}
			} 
			else {		
				if($.browser.msie || $.browser.msedge) {
					if(eligibleForReply(_form)){	// traffic traffic_cop
						handleIEReply(_form);		// stop saving draft for reply
						removeFormChangedFlag();	// flag reset on submit
						return true;
					}
					return false;
				} else {
					ev.preventDefault();
					blockConversationForm(_form);
					if(!isFormLocked(_form)) {
						lockForm(_form);
						submitNewConversation(_form, ev, afterTktPropertiesUpdate);	
					} else{
						//Repeated submission, do something
						console.log('Duplicate Request Blocked');
					}
					
				}
			}

		} else {
			_form.find('input[type=submit]').prop('disabled', false);
		}

		removeFormChangedFlag();
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

	jQuery('#ticket-association').trigger('afterShow');

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

	

	window.submitNewConversation = function(_form, ev, callback) {
		
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
				releaseForm(_form);
				var statusChangeField = $('#send_and_set');

				if(App.Tickets.TicketDetail.inlineError) {
					var msg = App.Tickets.TicketDetail.inlineErrorMessage;
					App.Tickets.LimitEmails.appendErrorMessage(_form,'.cc_fields:visible:last' ,msg)
					
					if (_form.data('panel')) {

						if(_form.data("form")){
							var $form = $('#' + _form.data('panel')),
								form_container = $form.find(".commentbox");

							form_container.unblock();
						} else {
							$('#' + _form.data('panel')).unblock();
						}
					}
					$.scrollTo(jQuery('.redactor.conversation_thread'));
					return false;
				}

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
					$('#selectAgentsOptions').select2('data',[]);
					var default_agent_present = $('.email_container.add_select2_custom').data('default-agent');
					var default_agent_option = $('.email_container.add_select2_custom').data('default-agent-disp');
					if ( default_agent_present){
						$('#selectAgentsOptions').val(default_agent_present).trigger('change');
					}
					_form.find('select.select2').trigger('change'); //For resetting the values in Select2.

					if (_form.attr('rel') == 'forward_form')  {
						//Remove To Address
						_form.find('.forward_email li.choice').remove();
					}

					if (_form.attr('rel') == 'note_form')  {
            _resetPrivateNoteToggle(_form);
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
						var panel = _form.data('panel');
						var form_el = $('#' + panel);
						form_el = _form.data("form") ? form_el.find(".commentbox") : form_el;
						form_el.unblock();
						
					}
					$('#file_size_alert_' + _form.data('cntId')).show();

					if (_form.data('cntId') && _form.data('cntId') == 'cnt-reply') {
						triggerDraftSaving();
					}
				}

				if(_form.attr('rel') == 'tweet_form'){
					getTweetTypeAndBind();
				}

				resetInlineAttachments(_form);

				_form.data("formChanged",false)

				Helpdesk.TicketStickyBar.check();

			},
			error: function(response) {
				releaseForm(_form);
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

  	var send_and_set_a = function(_form, ev, callback){

		var tkt_form = $('#custom_ticket_form');
		var submit = $('#custom_ticket_form .btn-primary');
		submit.button('loading');
		submit.attr('disabled','disabled');

		var isNotesVisible = $('#all_notes').length > 0;

	    // Ajax Parameters stored in DOM
	    [
	      { name: 'format', value: 'js'},
	      { name: 'showing', value: isNotesVisible ? 'notes' : 'activities'},
	      { name: 'since_id', value: isNotesVisible ? TICKET_DETAILS_DATA['last_note_id'] : TICKET_DETAILS_DATA['last_activity']}
	    ].map(function(x) {
	      return $('<input type="hidden" rel="ajax_params" name="' + x.name + '" value="' + x.value + '" />');
	    }).forEach(function(y) {
	      _form.append(y);
	    });
		seperateQuoteText(_form);
		if (_form.data('cntId') && _form.data('cntId') == 'cnt-reply') {
			stopDraftSaving();
		}

		callback = callback || function(){};

		$.ajax({
			type: 'POST',
			url: TICKET_DETAILS_DATA["displayId"] + '/send_and_set_status',
			dataType: 'script',

			data: jQuery.merge(_form.serializeArray(), tkt_form.serializeArray()),

			success: function(response, statusCode, xhr) {

			  releaseForm(_form);
			  var statusChangeField = $('#send_and_set');

			  function _unblockForm(){
			    if (_form.data('panel')) {
			      if(_form.data("form")){
			        var $form = $('#' + _form.data('panel')),
			            form_container = $form.find(".commentbox");

			        form_container.unblock();
			      } else {
			        $('#' + _form.data('panel')).unblock();
			      }
			    }
			  }

			  function _unblockPanel(){
			    if (_form.data('panel')) {
			      $('#' + _form.data('panel')).unblock();
			    }
			  }

			  function _saveDraft(){
			    if (_form.data('cntId') && _form.data('cntId') == 'cnt-reply') {
			      triggerDraftSaving();
			    }
			  }

			  if(App.Tickets.TicketDetail.inlineError) {
			    var msg = App.Tickets.TicketDetail.inlineErrorMessage;
			    App.Tickets.LimitEmails.appendErrorMessage(_form,'.cc_fields:visible:last' ,msg);

			    _unblockForm();

			    $.scrollTo(jQuery('.redactor.conversation_thread'));
			    return false;
			  }
			  if($('#response_added_alert').length > 0 && _form.parents('#all_notes').length < 1){
			    // if activities shown

			    _unblockPanel();
			    _saveDraft();

			    _form.trigger('focusin.keyboard_shortcuts');

			    if(statusChangeField.data('val') != undefined && statusChangeField.data('val') != ""){
			      changeStatusTo(currentStatus);
			      statusChangeField.data('val','');
			      $('.ticket_details #helpdesk_ticket_status').data('updated',false);
			    }
			  }else if($.trim(response).length){
			    // after successful note
			    _unblockForm();
			    if (_form.data('panel')) {
			      $('#' + _form.data('panel')).hide();
			      $('#' + _form.data('panel')).trigger('visibility');
			    }

			    if (_form.data('cntId') && _form.data('destroyEditor')){
			      $('#' + _form.data('cntId') + '-body').destroyEditor(); //Redactor
			    }

			    _form.resetForm();
			    _form.trigger('reset');
			    $('#selectAgentsOptions').select2('data',[]);
			    var $select2Custom = $('.email_container.add_select2_custom');
			    var default_agent_present = $select2Custom.data('default-agent');
			    var default_agent_option = $select2Custom.data('default-agent-disp');

			    if ( default_agent_present){
			      $('#selectAgentsOptions').val(default_agent_present).trigger('change');
			    }
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

			    _unblockPanel();
			    $('#file_size_alert_' + _form.data('cntId')).show();

			    _saveDraft();
			  }

			  if(_form.attr('rel') == 'tweet_form'){
			    getTweetTypeAndBind();
			  }

			  _form.data("formChanged",false);

			  Helpdesk.TicketStickyBar.check();

			  var property_response = tkt_form.data('send_and_set_resp');

			  TICKET_DETAILS_DATA['updating_properties'] = false;
			  submit.val(submit.data('saved-text')).addClass('done');
			  setTimeout( function() {
			    submit.button('reset').removeClass('done');
			  }, 2000);


			  if(property_response.err_msg){
			    jQuery("#noticeajax").html(property_response.err_msg).show();
			      closeableFlash('#noticeajax');
			        jQuery(document).scrollTop(0);
			  }
			  else{

			    if (property_response.autoplay_link) {
			      pjaxify(property_response.autoplay_link);
			    }
			    else if(property_response.redirect || property_response.autoplay_link == ""){
			      $('[rel=link_ticket_list]').click();
			    } 
			    else {
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
			  }
			  tkt_form.removeData('send_and_set_resp');

			},
			error: function(response) {
			  releaseForm(_form);
			  //_enableUpdateButton();
			  _form.find('input[type=submit]').prop('disabled', false);
			  _unblockPanel();
			  _saveDraft();
			  //_enableActionButton();
			  submit.text(submit.data('default-text')).prop('disabled',false);

			}
		});


	};

	/*
	 * Below functions are introduced to prevent duplicate form submission, that is
	 * caused due to unknown reason.!
	 */

	var lockForm = function(_form){
		_form.data('submitting','true');
	}

	var releaseForm = function(_form){
		_form.data('submitting','false');
	}

	var isFormLocked = function(_form){
		return (_form.data('submitting') == 'true');
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

				if(response.err_msg){
					jQuery("#noticeajax").html(response.err_msg).show();
    				closeableFlash('#noticeajax');
        			jQuery(document).scrollTop(0);
				}else{
					callback();
				
					if (response.autoplay_link) {
						pjaxify(response.autoplay_link);
					}
					else if(response.redirect || response.autoplay_link == "")
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
		var fields_to_check = ['priority', 'status', 'group_id', 'ticket_type', 'product', 'source','company_id'];
		for(i in fields_to_check) {
			if (typeof(fields_to_check[i]) == 'string' && $('.ticket_details #helpdesk_ticket_' + fields_to_check[i]).data('updated')) {
				postProcess = true;
				break;
			}
		}
		var ticket_fields = tkt_form.find(':input');
		var data_hash = {};

		ticket_fields.each(function() {
			if($(this).data().updated) {
				var field_name = $(this).attr('name');
        var lbl_val;

        if($(this).attr("type") == "checkbox"){
          lbl_val = $(this).is(":checked")
        } else {
          lbl_val = $(this).val()
        }
        if(typeof field_name != "undefined"){
					data_hash[field_name] = {
						value: lbl_val,
						datatype: $(this).get(0).tagName.toLowerCase(),
						type: field_name.match(/\[.*?\]/)[0] == "[custom_field]" ? "custom_field" : "default" ,
						required: $(this).hasClass('required'),
	          name: $(this).find("option:selected").text()
					};
        }
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
			if(TICKET_DETAILS_DATA['requester_widget_enabled'] && TICKET_DETAILS_DATA['user_valid'])
				refreshRequesterWidget();
		}
	}

	window.closeCurrentTicket = function (ev) {
		changeStatusTo(TICKET_CONSTANTS.statuses.closed);
		if($('#custom_ticket_form').valid())
		{
			var action_attr = $('#custom_ticket_form').attr("action").split("?")[0];
			var isSilentClose = ev.shiftKey || false,
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
		if (editorId != 'send-tweet-cnt-reply-body' && editorId != 'send-fb-post-cnt-reply-body' && editorId != 'send-ecommerce-post-cnt-reply-body' ){
			$('#'+editorId).data('redactor').saveSelection();
		}
		$('#canned_response_show').trigger('click');
	});

	$('body').on('click.ticket_details', 'a[rel="ticket_solutions"]', function(ev){
		ev.preventDefault();
		$('#suggested_solutions_show').data('editorId', $(this).data('editorId'));
		var editorId = $('#suggested_solutions_show').data('editorId');
		if (editorId != 'send-tweet-cnt-reply-body' && editorId != 'send-fb-post-cnt-reply-body' && editorId != 'send-ecommerce-post-cnt-reply-body'){
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

      // Reset Add Private Note button
      if ($(this).data('note-type') === 'note')  {
          var $form = $('#cnt-' + $(this).data('note-type'));
          _resetPrivateNoteToggle($form);
		  }

		//code for collapsing the broadcat message box
		if(parseFloat($('.broadcast_message_box #ticket_original_request [dir="ltr"]').css('height')) > 64) {
			$('.broadcast_message_box #ticket_original_request').addClass('collapsed');
			$('#recent_broadcasted_message .quoted_text').css('display', 'inherit');
		}
		//hiding attachment button while adding broadcast message
		$('#cnt-broadcast #attachment-options-note').css('display', 'none');
		//appending the broadcast message into reply---changes for linked tickets field
		if($(this).data('reply-type') === 'broadcast'){
			var element_id = $(this).data('editorId'),
			$element = jQuery('[id$=' + element_id +']');
			var broadcastMsg = $('.broadcast_message_box #ticket_original_request div').html();

			if($element.data('redactor')){
				$element.data('redactor').saveSelection();

				if($element){
					$element.data('redactor').insertOnCursorPosition('inserthtml',broadcastMsg);
					$element.getEditor().focus();
			 	}
			}else {
				var existingReplyMsg = $('[id$=cnt-reply-body]').val();
				$('[id$=cnt-reply-body]').val(existingReplyMsg+'<br/>'+broadcastMsg).trigger('change');
			}
		}

	  	if ($('#cnt-reply').data('isTwitter')) {
			getTweetTypeAndBind();
	  	}
	  	if($('#cnt-reply').data('is-facebook-realtime-dm') && $('#send-fb-post-cnt-reply-body').hasClass('facebook-realtime')) {
	  		bindFacebookDMCount();
	  	}

		swapEmailNote('cnt-' + $(this).data('note-type'), this);
	});

	//binding Discuss button
  $('body').on('click.ticket_details', '[id=DiscussButton]', function(ev) {
  	$("#collab-btn").trigger("click");
  	ev.preventDefault();
		ev.stopPropagation();
  });

	$('body').on('click.ticket_details', '[rel=review-button]','[id=ReviewButton]', function(ev) {
		if(confirm("Do you want to send request for App review?")) {
			$("#HelpdeskReviewNotes").submit();
		}
		ev.preventDefault();
		ev.stopPropagation();
	});

	//show full broadcast message
	if(parseFloat($('.broadcast_message_box #ticket_original_request [dir="ltr"]').css('height')) <= 65) {
		$('.broadcast_message_box #ticket_original_request').removeClass('collapsed');
		$('.broadcast_message_box .quoted_text').css('display', 'none');
	}
	
	$('body').on('click.ticket_details', '.broadcast_message_box .quoted_text, .boadcast_expander', function(e){
		e.preventDefault();
		$('.broadcast_message_box #ticket_original_request').removeClass('collapsed');
		$('.broadcast_message_box .quoted_text').css('display', 'none');
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

	jQuery('body').on('click.ticket_details', '.freshdesk_quote .q-marker', function(){
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
	        	 _messageDiv.find('.tooltip').twipsy('hide');
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
		$.ajax({
			type: 'GET',
			url: tkt_prop.data('remoteUrl'), 
			success: function(data){
				tkt_prop.html(data);
       	 		tkt_prop.data('remoteUrl', false);
				$('body').on('change.ticket_details', '#custom_ticket_form', function(ev) {
			
					if (!dontAjaxUpdate) 
					{
						TICKET_DETAILS_DATA['updating_properties'] = true;
						$(ev.target).data('updated', true);
						$('#custom_ticket_form').data('updated', true);
					}
					dontAjaxUpdate = false;
				});
			trigger_event("sidebar_loaded",{name: "ticket_properties", dom_id: "#TicketProperties"});
		}});	
	})()

	trigger_event("ticket_view_loaded",{});

	//RECENT TICKETS SETUP
	NavSearchUtils.saveToLocalRecentTickets(TICKET_DETAILS_DATA);	

	// Check for when form changes occur
	var selectors = [
		".form-unsaved-changes-trigger input",
		".form-unsaved-changes-trigger textarea",
		".form-unsaved-changes-trigger .redactor_editor",
		".form-unsaved-changes-trigger select"
	];
	$('body').on('change.ticket_details input.ticket_details', selectors.join(","), function(event){
		// Ignore twitter handle and type changes
		if(["twitter_handle","tweet_type"].indexOf($(event.target).attr('id'))>-1){
			return;
		}
		var form = $(event.target).parents('.form-unsaved-changes-trigger');
		form.data("formChanged",true);
	})

	function removeFormChangedFlag(){
		// Remove formChanged field in the form on any submit
		$(".form-unsaved-changes-trigger").each(function(){$(this).data("formChanged",false)});
	}

	// Need to set this on global for Fjax.js
	if(typeof customMessages=='undefined') customMessages = {};
	customMessages.confirmNavigate = TICKET_DETAILS_DATA.confirm_navigation;

};
// TICKET DETAILS DOMREADY ENDS

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
		"todo_loaded",
		"time_entry_loaded",
		"watcher_added",
		"watcher_removed"
	];

	for(var i=0; i<custom_events.length ; i++){
		jQuery(document).off(custom_events[i]);
	}
};

	
App.Tickets.TicketDetail = {
	inlineError: false,
	inlineErrorMessage: '',
	setInlineMessage: function (status, msg) {
		this.inlineError = status;
		this.inlineErrorMessage = msg;
	},
	onVisit: function (data) {
		TICKET_DETAILS_DOMREADY();
		
		if($("#HelpdeskReply").data('containDraft')) {
			swapEmailNote('cnt-reply', null);
			TICKET_DETAILS_DATA['draft']['hasChanged'] = false;
			jQuery(window).trigger('scroll');
		}

		App.Tickets.Watcher.init();
		App.Tickets.Merge_tickets.initialize();
		App.TicketAttachmentPreview.init();
		App.Tickets.NBA.init();
		App.Tickets.TicketRequester.init();

		// Have tried in onLeave to off all the event binding. 
		// But it cause errors in whole app, like modal, dropdown and some issues has occered.
		Fjax.afterNextPage = TICKET_DETAILS_CLEANUP;

		if(typeof App.CollaborationUi !== "undefined") {
			App.CollaborationUi.askInitUi();
		} else {
			var collab_btn = jQuery("#collab-btn");
			if(collab_btn.length) {
				collab_btn.addClass("hide");
            	console.info("Did not start collaboration. CollaborationUi script was not loaded.");
			}
		}
	},
	onLeave: function() {
		App.Tickets.Merge_tickets.unBindEvent();
		App.Tickets.Watcher.offEventBinding();
		App.TicketAttachmentPreview.destroy();
		App.Tickets.NBA.offEventBinding();
		
		if(!!App.CollaborationUi && typeof App.CollaborationUi.unbindEvents === "function") {
			App.CollaborationUi.unbindEvents();
		}
		
		App.Tickets.TicketRequester.unBindEvents();
	}
};


App.Tickets.LimitEmails = {
	new_cc_bcc_emails: [],
	limitForwardEmails: function(form, append_to, tkt_addr_arr, limit, msg) {
	    var cc_emails  = [];
	    var bcc_emails = [];
	    var to_emails  = [];
	    var fwd_emails = [];

	    var _self = this;

	    form.find("input[name='helpdesk_note[to_emails][]']").each( function() {
	      to_emails.push(_self.get_email_address(jQuery(this).val()));
	    });

	    form.find("input[name='helpdesk_note[cc_emails][]']").each( function() {
	      cc_emails.push(_self.get_email_address(jQuery(this).val()));
	    });

	    form.find("input[name='helpdesk_note[bcc_emails][]']").each( function() {
	      bcc_emails.push(_self.get_email_address(jQuery(this).val()));
	    });

	    var current_emails = to_emails.concat(cc_emails, bcc_emails)

	    fwd_emails = this.new_cc_bcc_emails.concat(tkt_addr_arr, current_emails );
	    fwd_emails = jQuery.unique(fwd_emails);

	    if( tkt_addr_arr.length != fwd_emails.length && fwd_emails.length > limit ) {
	    	this.appendErrorMessage(form, append_to, msg);
	    	$.scrollTo(jQuery('.redactor.conversation_thread'));
	    	return false;
	    }

	    var newly_added_emails = this.new_cc_bcc_emails.concat(current_emails)
	    this.new_cc_bcc_emails = jQuery.unique(newly_added_emails);

	  	return true;
	},
	limitReplyEmails: function(_form, append_to, tkt_addr_arr, limit, msg) {
	    var cc_emails  = []
	    var bcc_emails  = []
	    var reply_emails = []

	    var _self = this;

	    _form.find("input[name='helpdesk_note[cc_emails][]']").each( function() {
	      cc_emails.push(_self.get_email_address(jQuery(this).val()));
	    });

	    _form.find("input[name='helpdesk_note[bcc_emails][]']").each( function() {
	      bcc_emails.push(_self.get_email_address(jQuery(this).val()));
	    });

	    var current_emails = cc_emails.concat(bcc_emails)

	    reply_emails = this.new_cc_bcc_emails.concat(tkt_addr_arr, current_emails );
	    reply_emails = jQuery.unique(reply_emails);

	    if( tkt_addr_arr.length != reply_emails.length && reply_emails.length > limit ) {
	    	this.appendErrorMessage(_form, append_to, msg);
	    	$.scrollTo(jQuery('.redactor.conversation_thread'));
	    	return false;
	    }

	    var newly_added_emails = this.new_cc_bcc_emails.concat(current_emails)
	    this.new_cc_bcc_emails = jQuery.unique(newly_added_emails);
		return true;
	},
	limitComposeEmail: function(_form, append_to, limit, msg) {
	    var cc_emails  = []
	    var to_email = []

	    _form.find("input[name='cc_emails[]']").each( function() {
	      cc_emails.push(App.Tickets.LimitEmails.get_email_address(jQuery(this).val()));
	    });

	    to_email.push(App.Tickets.LimitEmails.get_email_address(_form.find("input[name='helpdesk_ticket[email]']").val()))
	    var current_emails = cc_emails.concat(to_email)
	    current_emails = jQuery.unique(current_emails);
	    
		if((current_emails.length) > limit) {
				this.appendErrorMessage(_form, append_to, msg);

		    return false;
		}
		return true;
	},
	appendErrorMessage: function(_form, append_to ,msg) {
		if(!_form.find(".text-error").get(0)){
			_form.find(append_to).append("<p class='cc-error-message text-error'> "+msg+"</p>")	
		}
	},
	getNewlyAddedEmails: function() {
		return this.new_cc_bcc_emails;
	},
	get_email_address: function(string) {
		whole_match = /"?(.+?)"?\s+<(.+?)>/
		res =  whole_match.exec(string)
		if(res) {
    		return res[2]
		}
	  	with_brackets =  /<(.+?)>/
	  	res =  with_brackets.exec(string)
		if(res) {
    		return res[1]
		}
	   	return string
	}

}

    /**
       Reset the Add Private Note toggle and
       set the add note button caption to default value , 'Add Private Note' 

       @params:
        $form - jQuery form object to find the submit button

    **/
    function _resetPrivateNoteToggle($form) {
        $('#toggle-note-visibility .toggle-button').addClass('active');
				var $submitBtn = $form.find('.submit_btn');
				$submitBtn.find('[rel=text]').text($submitBtn.data('defaultText'));
    }

	function resetInlineAttachments(_form){
		_form.find(".inline-attachment-input").remove();
	}

}(window.jQuery));


