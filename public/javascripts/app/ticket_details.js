(function($) {
// Initialisation
TICKET_DETAILS_DATA['updating_properties'] = false;
$('#helpdesk_ticket_submit').hide();
//Ticket Properties Update Ajax Function
var ticket_update_timeout;
var tmp_count = 0;


//Agents updation on Group Change.


var dontAjaxUpdate = false;
var deferredTicketUpdate = function(timeout) {
    timeout = timeout || 3000;
    if (typeof(ticket_update_timeout) != 'undefined') {
        clearTimeout(ticket_update_timeout);
    }

    if ($('#custom_ticket_form').valid()) {
        ticket_update_timeout = setTimeout(function() {
            $('#custom_ticket_form').submit();
        },3000);
    }

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


$('#helpdesk_ticket_group_id').bind("change", function(e){
    $('#TicketProperties .default_agent')
        .addClass('loading-right');

    $.ajax({type: 'POST',
        url: '/helpdesk/tickets/get_agents/'+this.value,
        contentType: 'application/text',
        success: function(data){
            $('#TicketProperties .default_agent select')
                .html(data)
                .trigger('change');

            $('#TicketProperties .default_agent').removeClass('loading-right');
          }
    });
});
changeAggentList = function(group_id)
{
    console.log('changeAggentList');
}

function dueDateSelected(date){
new Date(date);
}

var fetchLatestNotes = function() {
    $.ajax({
        url: TICKET_DETAILS_DATA['fetch_notes_url'],
        type: 'GET',
        data: {last_note: TICKET_DETAILS_DATA['last_note_id']},
        success: function(response) {
            $('#all_notes').append(response);
            console.log('completed');
            console.log('Last Note: ' + TICKET_DETAILS_DATA['last_note_id']);
        }
    });
}
//   Copied from Old Show Page
var activeForm = null;
swapEmailNote = function(formid, link){
    $('#TicketPseudoReply').hide();

    if((activeForm != null) && ($(activeForm).get(0).id != formid))
        $("#"+activeForm.get(0).id).hide();


    activeForm = $('#'+formid).show();
    switch(formid){
        case 'cnt-reply':
        case 'cnt-note':
        case 'cnt-fwd':
            invokeRedactor(formid+"-body",formid);
            $('#'+formid+"-body").getEditor().focus();
            if($.browser.mozilla){
                $('#'+formid+"-body").insertHtml("<div/>");//to avoid the jumping line on start typing 
            }
            $('#'+formid+"-body").getEditor().on('blur',function(){
            $('#'+formid+"-body").data('focus_node',document.getSelection().getRangeAt(0).endContainer);
            $('#'+formid+"-body").data('focus_node_offSet',document.getSelection().getRangeAt(0).endOffset);

        });

        break; 
        case 'cnt-fb-post': 
            setCaretToPos($('#send-fb-post-cnt-fb-post-body'), 0); 
        break;
        case 'cnt-tweet' : 
            setCaretToPos($('#send-tweet-cnt-tweet-body'), 0);
        break;
    }
}

var activeTinyMce = null;
function show_canned_response(button, ticket_id){
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

     
function insertIntoConversation(value,element_id){
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

function getCannedResponse(ticket_id, ca_resp_id){
    jQuery("#canned_response_container").addClass("loading")
    jQuery.ajax({   type: 'POST',
                url: '/helpdesk/canned_responses/show/'+ticket_id+'?ca_resp_id='+ca_resp_id,
                contentType: 'application/text',
                async: false,
                success: function(data){        
                            insertIntoConversation(data,activeTinyMce);

                        jQuery("#canned_response_list")
                          .removeClass("loading")
                          .hide(300);
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
    var total_count;
    if (showing_notes)
        total_count = TICKET_DETAILS_DATA['total_notes'];
    else
        total_count = TICKET_DETAILS_DATA['total_activities'];

    var loaded_items = $('#all_notes li.conversation').length;
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
        var showing_notes = $('#all_notes').length() > 0;
        $('#show_more').data('next-page',2);
        $('#show_more').on('click',function(ev) {
            ev.preventDefault();
            $('#show_more').addClass('loading');
            var href = TICKET_DETAILS_DATA['notes_pagination_url'] + $(this).data('next-page').toString();
            $.get(href, function(response) {
                $('#show_more').removeClass('loading');
                $('#all_notes').prepend(response);
                $('#show_more').data('next-page',$('#show_more').data('next-page') + 1);
                updateShowMore();
            });
        });
        
    }   
}

// ----- END FOR REVERSE PAGINATION ------ //



$(document).ready(function() {
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
            // Make the old tab inactive.
            $active.parent().removeClass('active');
            $content.hide();

            // Update the variables with the new link and content
            $active = $(this);
            $content = $($(this).attr('href'));

            // Make the tab active.
            $active.parent().addClass('active');
            $content.show();

            // Prevent the anchor's default click action
            e.preventDefault();
        });
    });

    $("select").data('placeholder','');
    $("select.dropdown, select.dropdown_blank, select.nested_field, #reply_email_id, select.select2").livequery(function(){
        if (this.id == 'helpdesk_ticket_priority') {
            $(this).select2({
                formatSelection: formatPriority,
                formatResult: formatPriority,
                escapeMarkup: escapePriority,
                specialFormatting: true,
                minimumResultsForSearch: 5,
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
            tokenSeparators: [','],
        });
    })

    // $("[rel=autocomplete_emails]").livequery(function(){
    //     $(this).select2({
    //         tokenSeparators: [','],
    //         tags: function() {
    //             console.log(this)
    //         },
    //         minimumInputLength: 1,
    //         ajax: {
    //             url: '/helpdesk/authorizations/autocomplete',
    //             dataType: 'json',
    //             data: function(term, page) {
    //                 return {
    //                     v: term
    //                 };
    //             },
    //             results: function (response, page) {
    //                 console.log(response);
    //                 return response;
    //             }
    //         },

    //         formatSelection: formatEmailNames,
    //         formatResult: formatEmailNames
    //     });
    // });

    //   ABOVE EMAIL-AUTOCOMPLETE NOT BEING USED - REMOVE AFTER REVIEW

    //For Clearing Bcc, Cc email list and hiding those containers

    $('[rel=toggle_email_container]').live('click',function(ev) {
        ev.preventDefault();
        var container = $('#' + $(this).data('container'));
        var select = $('#' + $(this).data('container') + ' select');

        container.toggle();
        if (container.is(':visible')) {
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
    $('.ticket_show #show_activities').live('click', function(ev) {
        ev.preventDefault();
        $('#show_more').data('next-page',null); 
        $('#show_more').addClass('hide');
        //Resetting
        $.ajax({
            url: TICKET_DETAILS_DATA['activities_pagination_url'],
            success: function(response) {
                $('#all_notes').replaceWith(response);
                updatePagination();
            }
        })
    })

    $("#TicketForms form").live('submit', function(ev) {
        ev.preventDefault();
        jQuery(this).ajaxSubmit({
            dataType: 'xml',
            beforeSubmit: function(values, form) {
                var format = $('<input type="hidden" name="format" value="xml" />');
                $(form).append(format);
            },
            success: function(response) {
                fetchLatestNotes();
                $('#TicketForms .request_panel:visible').slideUp(function() {
                    $('#TicketPseudoReply').show();
                });
            }
        });
    });

    $('[rel=TicketReplyPlaceholder]').live('click', function(ev) {
        ev.preventDefault();
        $(this).hide();
        $('#ReplyButton').click();
    });

	// -----   START OF TICKET BAR FIXED TOP ------ //
	//For having the ticket subject and the action bar floating at the top when Scrolling down	
	REAL_TOP = $("#wrap .header").first().height();
	var the_window = $(window);

	the_window.scroll(function () {
	    if (the_window.scrollTop() > REAL_TOP) {
    		$('.fixedStrap').addClass('at_the_top');
    		$('.scollable_content').css({marginTop:$('.fixedStrap').outerHeight()});
    		$('#firstchild').addClass('firstchild');

	    } else {
	    	$('.fixedStrap').removeClass('at_the_top');
    		$('.scollable_content').css({marginTop:''});
    		$('#firstchild').removeClass('firstchild');
	    }
    });
    // -----   END OF TICKET BAR FIXED TOP ------ //


    $('#custom_ticket_form').on('change',function(ev) {
        if (!dontAjaxUpdate) 
        {
            $('#helpdesk_ticket_submit').show();
            TICKET_DETAILS_DATA['updating_properties'] = true;
            var submit_timeout = 1500;
            if (ev.target.id == 'helpdesk_ticket_group_id') {
                return true;
                //Avoiding Updates firing for changes to Group Field
                //This will be fired after the Agents are loaded.
            }
            deferredTicketUpdate(submit_timeout);
        }
        dontAjaxUpdate = false;
    } );

    $('#custom_ticket_form').on('submit', function(ev) {
        ev.preventDefault(); 
        var submit = $('#helpdesk_ticket_submit');
        submit.val(submit.data('saving-text')).prop('disabled',true);
        var tkt_form = $('#custom_ticket_form');
        $.ajax({
            type: 'POST',
            url: tkt_form.attr('action'),
            data: tkt_form.serialize(),
            dataType: 'json',
            success: function(response) {
                TICKET_DETAILS_DATA['updating_properties'] = false;
                submit.val(submit.data('saved-text'))
                    .prop('disabled',true)
                    .hide('highlight',1500, function() {
                        submit.val(submit.data('default-text')).prop('disabled',false);
                    });
            },
            error: function(jqXHR, textStatus, errorThrown) {
                submit.text(submit.data('default-text')).prop('disabled',false);
                console.log('Errors');
                console.log(jqXHR);
                console.log(textStatus);
                console.log(errorThrown);
            }
        });
    });

    /*
        When the ticket subjects are long, we hide the extra content and show them only on mouseover. 
        While doing this, the ticket subject occupies more height that normal we are hiding that
        and showing that back on Mouseleave event.

        Being done to make sure that there is no visible jump in the infobox.
    */
    $('.ticket_show .control-left h2.subject').live('mouseenter', function(){
        if ($(this).height() > 30) {
            $(this).siblings('.ticket-actions').hide();
        }
    });
    $('.ticket_show .control-left h2.subject').live('mouseleave', function() {
        if (!$(this).siblings('.ticket-actions').is(':visible')) {
            $(this).siblings('.ticket-actions').show();
        }
    })


    //Binding the Reply/Forward/Add Note buttons
    $('[rel=note-button]').live('click', function(ev) {
        ev.preventDefault();
        swapEmailNote('cnt-' + $(this).data('note-type'), this);
    })
    //ScrollTo the latest conversation

    updatePagination();




    //Previous Next Buttons request
    // $.getScript("/helpdesk/tickets/prevnext/" + TICKET_DETAILS_DATA['displayId']);
});

// Capturing the Unload and making sure everything is fine, before we let the 
window.onbeforeunload = function(e) {
    var messages = [];
    if ($('#custom_ticket_form .error:input').length > 0 ) {
        messages.push('There are errors in the form.');
    }
    console.log("TICKET_DETAILS_DATA['updating_properties'] : " + TICKET_DETAILS_DATA['updating_properties']);
    if (TICKET_DETAILS_DATA['updating_properties']) {
        messages.push('Unsaved changes in the form');
    }

    console.log('unload');
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