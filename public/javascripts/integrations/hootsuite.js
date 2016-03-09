jQuery.noConflict();

(function ($) {

	Hootsuite = {
		initialize: function () {
      this.bindHsEvents();
      this.bindGroupChangeEvent();
      this.bindUpdateTicketEvent();
      this.bindWidgetEvent();
      this.bindSocialReplyEvent();
      this.bindAddReplyEvent();
      this.bindAddNoteEvent();
      this.openLinksInNewTab();
     },

    add_note: function(isPrivate,body){
			$('#alert').hide();
			var json_data = { "message": body, "id": window["ticketId"], "isPrivate": isPrivate, "authenticity_token": $('meta[name="csrf-token"]').attr("content"), "since_id": TICKET_DETAILS_DATA['last_note_id']};
			$.ajax({
				type: 'POST',
				url: '/integrations/hootsuite/tickets/add_note'+window["args"],
				contentType: 'application/json',
				data: JSON.stringify(json_data),
				success : function(data){
					if(typeof(data) == "object"){
						$('#alert').html(data.msg);
						$('#alert').show();
					}
					$('#note_body').val('');
					$('#note').find('.hs_btnTypeSubmit').text('Send').removeClass('disabled');
				}
			});
		},

		add_reply: function(body){
			var bcc = $(".bcc-input")[0].value;
			bcc = bcc.split(",");
			var cc = $(".cc-input")[0].value;
			cc = cc.split(",");
			var from = $(".from-mail").text();
			var json_data = { "message": body,"id": window["ticketId"],"bcc": bcc,"cc": cc,"from": from,"authenticity_token": $('meta[name="csrf-token"]').attr("content"), "since_id": TICKET_DETAILS_DATA['last_note_id']};
			$('#alert').hide();
			$.ajax({
				type: 'POST',
				url: '/integrations/hootsuite/tickets/add_reply'+window["args"],
				contentType: 'application/json',
				data: JSON.stringify(json_data),
				success: function(data) {
					if(typeof(data) == "object"){
						$('#alert').html(data.msg);
						$('#alert').show();
					}
					$('#msg_body').val('');
					$('#reply').find('.hs_btnTypeSubmit').text('Send').removeClass('disabled');
				}
			});
		},

		append_social_reply: function(){
			$.ajax({
	    type: 'GET',
	    url: '/integrations/hootsuite/tickets/append_social_reply'+window["args"]+"&id="+ticketId+"&since_id="+TICKET_DETAILS_DATA['last_note_id'],
		    success: function(data) {
				}
			});
		},

		bindAddNoteEvent: function(){
			var hs = this;
			$(document).on('click.hootsuite', '#add_ticket_note', function(ev){
			var body = $('#note_body').val();
			var isPrivate = !($("#helpdesk_ticket_private").prop('checked'));
			$(this).text('Please wait...').addClass('disabled');
			hs.add_note(isPrivate,body);
			});
		},

		bindAddReplyEvent: function(){
			var hs = this;
			$(document).on('click.hootsuite', '#add_ticket_reply', function(ev){
			var body = $('#msg_body').val();
			$(this).text('Please wait...').addClass('disabled');
			hs.add_reply(body);
			});
		},

		bindSocialReplyEvent: function(){
			var hs = this;
			$(document).on('click.hootsuite', '#social_reply', function(ev){
			ev.preventDefault();
			var rem = parseInt (jQuery("#SendTweetCounter").text());
			if(rem<0){
				return;
			}
			$('#alert').hide();
			$(this).val('Please wait...').addClass('disabled');
			var form = $('#social_reply_form');
			var formData = $(form).serialize();
			$.ajax({
			    type: 'POST',
			    url: $(form).attr('action')+window["args"],
			    data: formData,
			    success : function(data){
			    	hs.append_social_reply();
						$('#msg-body').val('');
						$('#social_reply').val('Reply Sent').removeClass('disabled');
			    },
			    error : function(data){
						$('#social_reply').val('Reply Sent').removeClass('disabled');
						$('#alert').html("Unable to send a reply");
						$('#alert').show();
			    }
				});
			});
		},

		bindWidgetEvent: function(){
			$(document).on('click.hootsuite', '.widget-top', function(ev){
			ev.preventDefault();
			$('.side-widget').hide();
			$('#'+$(this).data('show'))
				.show()
				.find('textarea')
				.focus();
			$('.widget-top').removeClass('active');
			$(this).addClass('active');
			});

			$(document).on('click.hootsuite', '.mail-options .option', function(ev) {
				ev.preventDefault();
				$(this).hide();
				$('.cc-bcc-input').show();
			});

			// Top bar controls and drop downs
			$(document).on('click.hootsuite', '.hs_topBarControlsBtn', function(e) {
				e.preventDefault();

				var $this = $(this);
				var $previousButton = $('.hs_topBarControlsBtn').filter('.active');
				var $previousDropdown = $('.hs_topBarDropdown').filter('.active');
				var dropdownDataValue = $this.data('dropdown');
				var previousDropdownDataValue = '';

				// Hide the previous drop down
				if ($previousDropdown.length) {
					previousDropdownDataValue = $previousDropdown.data('dropdown');
					$previousDropdown.hide().removeClass('active');               
					$previousButton.removeClass('active');
				}

				// Show the drop down associated with the clicked control button
				if (dropdownDataValue !== previousDropdownDataValue) {
					var $currentDropdown = $('.hs_dropdown' + dropdownDataValue);   
					$this.addClass('active');
					$currentDropdown.addClass('active').show(); 
					if (dropdownDataValue == 'Search' || dropdownDataValue == 'WriteMessage') {
						$currentDropdown.find('input[type="text"]').first().focus();
					}
				}
			});
		},

		bindUpdateTicketEvent: function(){
				$(document).on('submit.hootsuite', '#custom_ticket_form', function(ev) { //update ticket properties
				ev.preventDefault();
				$('#alert').hide();
				var form = $('#custom_ticket_form');
				var formData = $(form).serialize();
				var btn = $("#helpdesk_ticket_submit");
				btn.attr("value",btn.attr("data-loading-text"));
				btn.addClass('disabled');
				$.ajax({
				    type: 'POST',
				    url: $(form).attr('action')+window["args"],
				    data: formData
					}).done(function(data) {
							if(typeof(data) == "object" && data.status == "failed"){
							$('#alert').html(data.msg);
							$('#alert').show();
					  }
						btn.attr("value",btn.attr("data-saved-text"));
						btn.removeClass('disabled');
						setTimeout(function(){
						  btn.attr("value",btn.attr("data-default-text"));
						}, 2000);
					}).fail(function(data) {
					});
				return false;
			});			
		},

		bindGroupChangeEvent: function(){
			$(document).on('change.hootsuite', '#helpdesk_ticket_group_id', function(ev) {
				$('#helpdesk_ticket_responder_id').html("<option value=''>Loading...</option>");
				$.ajax({
			       type: 'GET',
			       url: '/helpdesk/commons/group_agents/'+window["args"]+'&id='+this.value,
			       contentType: 'application/text',
			       success: function(data){
			           $('#helpdesk_ticket_responder_id')
			             .html(data);
			        }
			     });
			});
		},

		bindHsEvents: function(){
			$(document).on('click.hootsuite', '.search_type', function(){
				var val = $(this).data('text');
				$('.hs_dropdownSearch #hs_searchInputExample').attr('placeholder', val);
			})

			
			// Any object with class custom-tip will be given a different tool tip
			$(".tooltip").twipsy({ live: true, placement: 'below' });	
		},

	 destroy: function () {
      $(document).off(".hootsuite");
   },

		openLinksInNewTab: function(){
			$(document).on('click.hootsuite', '.conversation a', function(ev){
				var link = $(this);
				var href = $.trim(link.attr("href"));
				if(href.indexOf("javascript:") == 0 || href=="#") return;
				window.open(href,"_blank");
				ev.preventDefault();
			});
		}
	};

	Hootsuite.initialize();
	showHideToEmailContainer = function(){
		$(".toEmailMoreContainer").toggle();
		if($(".toEmailMoreContainer").css("display") == "inline"){
			$(".toEmailMoreLink").text('');
		}
	}
	// Twitter handle
	$(document).on("change.hootsuite", '#twitter_handle', function (){
		var twitter_handle= $('#twitter_handle').val();
		var tweet_type = $('#tweet_type').val();
		var in_reply_to = $('#in_reply_to_handle').val();
		
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

	$(document).on("change.hootsuite", '#tweet_type', function (){
	  getTweetTypeAndBind();
	});

	function getTweetTypeAndBind(){
		var reply_type = $('#tweet_type').val(),
	  		count = (reply_type == 'dm') ? 10000 : 140;
	  
	  bindNobleCount(count);
	}

	function bindNobleCount(max_chars){
	  $('#msg-body').unbind();
	  
	  $('#msg-body').NobleCount('#SendTweetCounter', { on_negative : show_error , on_positive : hide_error, max_chars : max_chars });
	 }
})(jQuery);
