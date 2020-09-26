var FreshfoneEndCall;
(function ($) {
	"use strict";
	FreshfoneEndCall = function () {
		this.$widget = $('.freshfone_widget');
		this.$contentContainer = $('.freshfone_content_container');
		this.$endCall = this.$contentContainer.find('#end_call');
		this.$endCallQualityFeedbackContainer = this.$endCall.find('.quality_feedback_container');
		this.$feedbackComment = this.$endCall.find('#feedback_comment');
		this.$commentInput = this.$endCall.find('#bad_call_comment_box');
		this.$feedbackDropdown = this.$endCallQualityFeedbackContainer.find('#feedback_dropdown');
		this.$feedbackSelect = this.$endCallQualityFeedbackContainer.find('#feedback_select');
		this.$goodCallQuality = this.$endCallQualityFeedbackContainer.find('#good_rating');
		this.$badCallQuality = this.$endCallQualityFeedbackContainer.find('#bad_rating');
		this.$endCallAddToExistingButton = this.$endCall.find('.save_to_existing');
		this.$endCallMainContent = this.$endCall.find('.main_content');
		this.$endCallTicketSearch = this.$endCall.find('.end_call_ticket_search');
		this.$endCallShowSaveTicketFormButton = this.$endCall.find('.end_call_save');
		this.$endCallSaveTicketButton = this.$endCall.find('.save_ticket');
		this.$endCallNewTicketDetailsForm = this.$endCall.find('.new_ticket_details_form');
		this.$ticketSearchPane = this.$contentContainer.find('.ticket_search_pane');
		this.$ticketSearchType = this.$ticketSearchPane.find('#s2id_ticket-search-type');
		this.$endCallNote = $('#end_call_notes');
		this.$requesterNameContainer = this.$endCall.find('.requester_name_container');
		this.$requesterName = this.$requesterNameContainer.find("#requesterName");
		this.$requesterEmail = this.$requesterNameContainer.find("#requesterEmail");
		this.$requesterNumber = this.$requesterNameContainer.find("#requester_phone");
		this.$requesterEmailDom = this.$requesterNameContainer.find("#requesterEmail_dom");	
		this.$strangeNumberMessage = this.$requesterNameContainer.find("#strangeNumberMessage");
		this.$invalidEmailMessage = this.$requesterNameContainer.find("#invalidEmailMessage");
		this.$invalidNumberMessage = this.$requesterNameContainer.find("#invalidNumberMessage");
		this.$contactDetailsBlankMessage = 	this.$requesterNameContainer.find("#contactDetailsBlankMessage");
		this.$ticketSubject = this.$endCall.find("#ticketSubject");
		this.$requesterTicketSearch = this.$endCall.find('.end_call_ticket_search');
		this.$callNote = $('#call_notes');
		this.$endCallDoNotSaveButton = this.$endCall.find('.end_call_cancel');
		this.$endCallSaveToAdded = this.$endCall.find('.end_call_added_ticket');
		this.$endCallSaveToAddedTicketButton = this.$endCallSaveToAdded.find('.set-ticket-btn');
		this.$addedTicketSubject = this.$endCallSaveToAdded.find('.added_ticket_details').find('.added_ticket_subject');
		
		this.freshdialogOption = {
			backdrop: "static",
			height: "480px",
			keyboard: true,
			showClose: true,
			targetId: "#end_call",
			templateFooter: "",
			toggle: "popupbox",
			width: "480px",
			classes: 'persistent_modal quality_feedback_modal_body'
		};
		this.init();
		var self = this;
		
		// Ticket Search
		self.$endCallAddToExistingButton.bind('click', function (ev) {
			ev.preventDefault();

			self.$endCallMainContent.hide();
			self.$ticketSearchPane.show();
			self.$ticketSearchType.select2('focus');
		});

		self.$ticketSearchPane.find('.back').bind('click', function (ev) {
			ev.preventDefault();

			self.$ticketSearchPane.hide();
			self.$endCallMainContent.show();
			self.$endCallAddToExistingButton.focus();
		});
		
		self.$endCallNewTicketDetailsForm.find('.back, .cancel').bind('click', function (ev) {
			ev.preventDefault();
			self.$requesterName.select2('data',null);
			self.$endCallNewTicketDetailsForm.hide();
			self.$endCallMainContent.show();
			self.$endCallShowSaveTicketFormButton.focus();
		});
		
		
		self.$endCallShowSaveTicketFormButton.bind('click', function () {
			self.$endCallMainContent.hide();
			self.$requesterEmailDom.hide();
			self.hideWarnings();
			self.$endCallNewTicketDetailsForm.show();
			self.$ticketSubject.focus();
			self.$requesterName.val(self.number);

		});

		//Call quality feedback
		$(".good_call, .bad_call").on('click', function(){
			var rating = this.id == "good_rating" ? "good" : "bad";
			self.bindQualityActions(rating);
		});

		self.$feedbackSelect.on('select2-close', function (ev) {
			self.showCommentBar((self.$feedbackSelect.val() == "other_issues"));
		});

		// Requeser Field in new ticket form -- end call form
		self.$requesterName.select2({
			placeholder: 'Search or Add Requester',
			minimumInputLength: 1,
			multiple: false,
			ajax: {
				url: freshfone.requester_autocomplete_path,
				quietMillis: 1000,
				data: function (term) { 
					return {
						q: escapeHtml(term)
					};
				},
				results: function (data, page, query) {
					data.results.push({value: query.term, id: ''});
					return {results: data.results};
				}
			},
			formatResult: function (result) {
				var userDetails = result.email || result.mobile || result.phone;
				if(userDetails && (userDetails).trim() != "") {
					userDetails = "(" + userDetails + ")";
				} else {
					if (!result.id) { userDetails = freshfone.new_requester;}
				}

				return "<b>"+ escapeHtml(result.value) + "</b><br><span class='select2_list_detail'>" + 
								(userDetails) + "</span>"; 
			},
			formatSelection: function (result) {
				self.$requesterEmailDom.toggle(!result.id);
				self.$requesterEmail.val(result.email);
				self.$requesterNumber.val(result.phone || result.mobile);
				self.$requesterName.data("requester_id",result.id);
				self.$requesterName.val(escapeHtml(result.value));
				return escapeHtml(result.value);
			}
		});

		self.$feedbackSelect.select2({
			minimumResultsForSearch: -1
		});
	
		$(document).on('shown', '#end_call', function(){
			freshfoneendcall.$endCallNote.focus();
			if(freshfonewidget.isTicketAdded()){
				self.showSaveToAddedTicketWidget();
			}
		});

		self.$requesterName.on('select2-close',function(){
			setTimeout(function(){
				if(self.$requesterName.data('requester_id')){
					self.hideWarnings();
					self.$endCallSaveTicketButton.focus();
				}
				else if(self.$requesterName.val() != self.number){
					self.$requesterEmail.focus();
					if(!freshfonewidget.checkForStrangeNumbers(self.number)){
						self.$requesterNumber.val(self.number);
					}
					self.$requesterEmailDom.show();
				}
			}, 10);
		});
		
		// Action to perform after selecting ticket from search result Save to ticket
		self.$endCallTicketSearch.on('click', '.save_to_ticket', function (ev) {
			ev.preventDefault();
			
			self.ticketId = $(this).data('id');
			self.saveNewTicket();
		});
		// Action to perform after selecting cancel or save button after ending call

		self.$endCallSaveTicketButton.bind('click', function (ev) {
			ev.preventDefault();
   
			if((self.$requesterName.val() == self.number) || !self.form_valdation()){
				if(self.$requesterName.val() == self.number){
				  self.$requesterEmailDom.hide();
				}
				self.hideWarnings();
				self.$endCallSaveTicketButton.button('loading');
				self.saveToExisting();
			}
		});

		// Cancel or don't save
		self.$endCall.find('.end_call_cancel').click(function (ev) {
			ev.preventDefault();
			self.hideEndCallForm();
		});

		self.$endCallSaveToAddedTicketButton.click(function (ev) {
			ev.preventDefault();
			if(self.inCall) {
				self.ticketId = freshfonewidget.addedTicketId;
				self.saveNewTicket();
			}
		});

		self.$endCall.on('click','.unattach_added_ticket',function (event) {
			event.preventDefault();
			self.toggleSaveToTicketBoxes(true);
		});

		$(document).on('hide', '#end_call', function (ev) {
			if(self.inCall) { self.updateCallWorkTime(); }
			self.resetDefaults();
		});
	};
	
	FreshfoneEndCall.prototype = {
		init: function () {
			this.callSid = "";
			this.callStartTime = "";
			this.callerId = null;
			this.callerName = null;
			this.id = "";
			this.number = null;
			this.date = null;
			this.inCall = true;
			this.callRating = null;
			this.convertedToTicket = false;
			this.directDialNumber = "";
			this.resetForm();
		},
		loadDependencies: function (freshfonecalls, freshfoneuser, freshfonewidget) {
			this.freshfonecalls = freshfonecalls;
			this.freshfoneuser = freshfoneuser;
			this.freshfonewidget = freshfonewidget;
		},
		saveNewTicket: function () {
			trigger_event('saveticket');
			this.saveTicket(false);
			this.hideEndCallForm();
		},
		
		saveToExisting: function () {
			trigger_event('saveticket');
			this.saveTicket(true);
		},
		resetDefaults: function () {
			if (this.inCall) {
				if(!freshfone.isAcwEnabled){
					this.freshfoneuser.resetStatusAfterCall();
					if (!this.convertedToTicket) { this.freshfoneuser.updatePresence(); }
				}

				this.freshfonewidget.resetToDefaultState();
				this.freshfonecalls.init();
				this.freshfoneuser.init();
			}
			this.$requesterName.select2('data',null);
			this.init();
		},
		
		saveTicket: function (is_ticket) {
			this.convertedToTicket = true;
			this.ticket_notes = this.formatNotes(this.$endCallNote.val());

			if (this.inCall && !this.callSid) { this.setCallSid(); }
			is_ticket ? this.createTicket() : this.createNote();
		},
		formatNotes: function(text){
			var formatted_text = text.replace(/\n/g,"<br>");
			return formatted_text.replace(/\s/g,"&nbsp;");
		},
		setCallSid: function () {
			this.callSid = this.freshfonecalls.getCallSid();
		},
		createTicket: function () {
			$.ajax({
				type: 'POST',
				url: '/freshfone/create_ticket',
				dataType: 'script',
				data: {
					'id' : this.id,
					'CallSid': this.callSid,
					'call_log': this.ticket_notes,
					'requester_name': this.requesterName(),
					'custom_requester_id' : this.custom_requester_id(),
					'ticket_subject': this.ticketSubject(),
					'requester_email': this.requesterEmail(),
					'responder_id': this.agent || "", 
					'call_history': !this.inCall,
					'direct_dial_number': this.directDialNumber,
					'phone_number' : this.$requesterNumber.val()
				}
			});
		},
		createNote: function () {
			if (this.ticketId === undefined) { return false; }
			// this.ticketId = this.existingTicketInput.data('id');
			$.ajax({
				type: 'POST',
				url: '/freshfone/create_note',
				dataType: 'script',
				data: {
					'id' : this.id,
					'ticket': this.ticketId,
					'call_log': this.ticket_notes,
					'CallSid': this.callSid,
					'call_history': !this.inCall,
					'caller_name': this.callerName,
				}
			});
		},	
		custom_requester_id: function () {
			return this.$requesterName.data('requester_id');
		},
		requesterName: function () {
			return this.$requesterName.val();
		},
		requesterEmail: function () {
			return this.$requesterEmail.val();
		},

		ticketSubject: function () {
			return this.$ticketSubject.val();
		},
		resetForm: function () {
			this.$requesterEmailDom.hide();
			this.initQualityFeedbackContainer();
			this.hideWarnings();
			this.$ticketSearchPane.hide();
			this.$endCallNewTicketDetailsForm.hide();
			this.$endCallMainContent.show();
			
			this.$endCall.find('input[type=text], textarea').val('');
			this.$requesterName.val('');
			this.$ticketSubject.val('');
			this.$requesterTicketSearch.initializeRequester('');
		},
		copyCallNotes: function () {
			this.$endCallNote.val(this.$callNote.val());
		},
		showEndCallForm: function () {
			if (!$('#end_call').data('modal')) { $.freshdialog(this.freshdialogOption); }
			$('#end_call').modal('show');
			this.toggleSaveToTicketBoxes(true);
			
			if (this.inCall) { 
				this.copyCallNotes();
				this.$endCallQualityFeedbackContainer.show();
				this.setCallSid();
			}
			var callerId = (this.inCall) ? this.freshfonecalls.callerId : this.callerId;
			this.number = this.number || this.freshfonecalls.number;
			this.callerName = this.callerName || this.freshfonecalls.callerName;
			this.prefillForm();
			this.initRequesterValue();
		},
		prefillForm: function () {
			this.$requesterName.val(this.number);
			this.$ticketSubject.val(this.generateTicketSubject());
			this.$requesterTicketSearch.initializeRequester(this.callerName);
		},
		generateTicketSubject: function () {
			var date = (this.inCall) ? 'now' : this.date;
			return 'Call with ' + (this.callerName || "(" + this.formattedNumber() + ")") +
						' on ' + Date.parse(date).toString('ddd, MMM d @ h:mm:ss tt').replace(/\@/, 'at');
		},
		formattedNumber: function () {
			if (this.number === null) { return ""; }
			return formatInternational(this.callerLocation(), this.number);
		},
		callerLocation: function () {
			return countryForE164Number(this.number);
		},
		hideEndCallForm: function () {
			App.Phone.Metrics.push_event();
			this.hideFeedbackBoxes();
			if (!$('#end_call').data('modal')) { $.freshdialog(this.freshdialogOption); }
			$('#end_call').modal('hide');
		},
		initRequesterValue: function () {
			this.$requesterName.removeData('requester_id');
			var initData = this.$requesterName.val(),self = this;
			if(initData.blank() || freshfonewidget.checkForStrangeNumbers(initData)) { return;}

			if(this.freshfonecalls.callerInfo && this.freshfonecalls.callerInfo.id){
				self.$requesterName.select2("data",this.freshfonecalls.callerInfo);
			}
			else if(this.callerId){
				$.ajax({
					url: freshfone.requester_autocomplete_path,
					quietMillis: 1000,
					data: {customer_id: this.callerId,
								 q: this.number},
				}).done(function(data) {
					self.$requesterName.select2("data",data.results[0]);
					self.callerName = data.results[0].value;
					self.prefillForm(); //calling again so that proper requester is loaded while saving ticket from call
					                    //history for merged contacts.
				});
			}
		},
    updateCallWorkTime: function() { 
      var self = this;
      if (!this.callSid) { this.setCallSid(); }
      $.ajax({
        type: 'PUT',
        url: '/freshfone/conference_call/wrap_call',
        data: {
					'CallSid': self.callSid,
					'rating': self.callRating,
					'issue' : self.$feedbackSelect.val(),
					'comment': self.$commentInput.val(),
					'id': self.freshfonecalls.callId
				}
      });
    },
		isValidEmail: function (freshfone_email){
			return (/^((([a-z]|\d|[!#\$%&'\*\+\-\/=\?\^_`{\|}~]|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])+(\.([a-z]|\d|[!#\$%&'\*\+\-\/=\?\^_`{\|}~]|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])+)*)|((\x22)((((\x20|\x09)*(\x0d\x0a))?(\x20|\x09)+)?(([\x01-\x08\x0b\x0c\x0e-\x1f\x7f]|\x21|[\x23-\x5b]|[\x5d-\x7e]|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])|(\\([\x01-\x09\x0b\x0c\x0d-\x7f]|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF]))))*(((\x20|\x09)*(\x0d\x0a))?(\x20|\x09)+)?(\x22)))@((([a-z]|\d|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])|(([a-z]|\d|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])([a-z]|\d|-|\.|_|~|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])*([a-z]|\d|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])))\.)+(([a-z]|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])|(([a-z]|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])([a-z]|\d|-|\.|_|~|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])*([a-z]|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])))\.?$/i).test(freshfone_email)
		},
		hideWarnings: function(){
			this.$requesterNameContainer.find('.error_message').toggle(false);
		},
		form_valdation: function(){
			this.hideWarnings();
			return (this.detailsEmptyCheck() || this.emailFieldValidation());
		},
		detailsEmptyCheck: function(){
			if(this.requesterEmail().trim() == "" && this.$requesterNumber.val() == ""){
				var message_elem = this.selectElement();
				if(!this.freshfonewidget.checkForStrangeNumbers(this.number)){
					this.$requesterNumber.val(this.number); 
				}
				this.toggleWarning(message_elem, true);
				return true;
			}
		},
		selectElement: function(){
			return this.freshfonewidget.checkForStrangeNumbers(this.number)	? this.$strangeNumberMessage : this.$contactDetailsBlankMessage;
		},
		emailFieldValidation: function(){
			if(this.emailValidationResult()){
				this.toggleWarning(this.$invalidEmailMessage, true);
				return true;  
			}
		},
		emailValidationResult: function(){
			return this.requesterEmail().trim() != "" && !this.isValidEmail(this.$requesterEmail.val());
		},
		numberValdationResult: function(){
			return !this.$requesterName.data('requester_id') && this.$requesterNumber.val() != "" && !isValidNumber(this.$requesterNumber.val());
		},
		toggleWarning: function(elem , to_show){
			elem.toggle(to_show);
		},
		showCommentBar: function(to_show){
			this.$feedbackComment.toggle(to_show);
		},
		bindQualityActions: function(rating){
			rating == "good" ? this.goodCallActions() : this.badCallActions();
		},
		goodCallActions: function(){
			this.callRating = "good";
			this.hideFeedbackBoxes();
			this.$feedbackSelect.select2('data', null);
			this.toggleButtonClasses(this.$goodCallQuality, this.$badCallQuality);
		},
		badCallActions: function(){
			this.callRating = "bad";
			this.$feedbackDropdown.show();
			this.toggleButtonClasses(this.$badCallQuality, this.$goodCallQuality);
		},
		initQualityFeedbackContainer: function(){
			this.$endCallQualityFeedbackContainer.hide();
			this.hideFeedbackBoxes();
			this.$feedbackSelect.select2('data', null);
			this.$goodCallQuality.removeClass("active");
			this.$badCallQuality.removeClass("active");
		},
		hideFeedbackBoxes: function(){
			this.$feedbackDropdown.hide();
			this.$feedbackComment.hide();
		},
		toggleButtonClasses :function(selected, previous){
			selected.addClass("active");
			previous.removeClass("active");
			selected.blur();
		},
		showSaveToAddedTicketWidget: function(){
			this.toggleSaveToTicketBoxes(false);
			this.$addedTicketSubject.html('<b> #' + freshfonewidget.addedTicketId + '</b> ' +freshfonewidget.ticketSubject);
		},
		toggleSaveToTicketBoxes: function(to_show){
			this.$endCallSaveToAdded.toggle(!to_show);
			this.$endCallShowSaveTicketFormButton.toggle(to_show);
			this.$endCallAddToExistingButton.toggle(to_show);
			this.$endCallDoNotSaveButton.toggle(to_show);
		}
  };
}(jQuery));