(function($) {
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

    var formatPriority = function(item) {
        return "<i class='priority_block priority_color_" + item.id + "'></i>" + item.text; 
    }

    $("select").data('placeholder','');
    $("select.dropdown, select.dropdown_blank, select.nested_field").livequery(function(){
        if (this.id == 'helpdesk_ticket_priority') {
            $(this).select2({
                width: 'element',
                formatSelection: formatPriority,
                formatResult: formatPriority
            });
        } else {
            $(this).select2({
                width: 'element'
            }); 
        }
    });


    //   Copied from Old Show Page
    var activeForm = null;
    swapEmailNote = function(formid, link){  
        jQuery("#PagesTab").click();

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

    function showHideEmailContainer(){
        $(".ccEmailMoreContainer").toggle();
        if($(".ccEmailMoreContainer").css("display") == "inline"){
            $(".ccEmailMoreLink").text('');
        }
    }

    function showHideToEmailContainer(){
        $(".toEmailMoreContainer").toggle();
        if($(".toEmailMoreContainer").css("display") == "inline"){
            $(".toEmailMoreLink").text('');
        }
    }


    //  End of Old Show page copy

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

    $('#helpdesk_ticket_submit').hide();
    //Ticket Properties Update Ajax Function
    var ticket_update_timeout;
    var tmp_count = 0;


    var deferredTicketUpdate = function(timeout) {
        timeout = timeout || 3000;
        clearTimeout(ticket_update_timeout);
        ticket_update_timeout = setTimeout(function() {
            if ($('#custom_ticket_form').valid()) {
                $('#custom_ticket_form').submit();
            }
        },3000);
    }

    $('#custom_ticket_form').on('change',function(ev) {
        console.log(ev.target);
        if (ev.target.id == 'helpdesk_ticket_group_id' || $(ev.target).hasClass('nested_field')) {
            return true;
            //Avoiding Updates firing for changes to Group Field
        }
        deferredTicketUpdate();
    } );

    $('#custom_ticket_form').on('submit', function(ev) {
        ev.preventDefault(); 
        var tkt_form = $('#custom_ticket_form');
        $.ajax({
            type: 'POST',
            url: tkt_form.attr('action'),
            data: tkt_form.serialize(),
            dataType: 'json',
            success: function(response) {
                console.log('Success');
                console.log(response);
            },
            error: function(jqXHR, textStatus, errorThrown) {
                console.log('Errors');
                console.log(jqXHR);
                console.log(textStatus);
                console.log(errorThrown);
            }
        });
    });


    //ScrollTo the latest conversation







    // ----- CODE FOR REVERSE PAGINATION ------ //

    var updateShowMore = function() {
        var loaded_items = $('#all_notes li.conversation').length;
        if (loaded_items < TICKET_DETAILS_DATA['total_notes']) {
            var remaining_notes = TICKET_DETAILS_DATA['total_notes'] - loaded_items;
            $('#show_more [rel=count-total-remaining]').text(TICKET_DETAILS_DATA['total_notes'] - loaded_items);
            
            if (remaining_notes > TICKET_DETAILS_DATA['notes_per_page']) {
                $('#show_more [rel=count-in-next-page]').text(TICKET_DETAILS_DATA['notes_per_page']);    
            } else {
                $('#show_more .commentbox').text('Show the remaining activities');
            }
            $('#show_more').removeClass('hide');
            return true;
        } else {
            $('#show_more').addClass('hide');
            return false;
        }
    }

    if (updateShowMore()) {
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

    // ----- END FOR REVERSE PAGINATION ------ //


    //Previous Next Buttons request
    // $.getScript("/helpdesk/tickets/prevnext/" + TICKET_DETAILS_DATA['displayId']);
});
})(jQuery);