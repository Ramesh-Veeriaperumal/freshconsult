var FreshfoneEndCall;
(function ($) {
	"use strict";
	FreshfoneEndCall = function () {
		this.$widget = $('.freshfone_widget');
		this.$contentContainer = $('.freshfone_content_container');
		this.$endCall = this.$contentContainer.find('#end_call');
		this.$endCallAddToExistingButton = this.$endCall.find('.save_to_existing');
		this.$endCallMainContent = this.$endCall.find('.main_content');
		this.$endCallTicketSearch = this.$endCall.find('.end_call_ticket_search');
		this.$endCallShowSaveTicketFormButton = this.$endCall.find('.end_call_save');
		this.$endCallSaveTicketButton = this.$endCall.find('.save_ticket');
		this.$endCallNewTicketDetailsForm = this.$endCall.find('.new_ticket_details_form');
		this.$ticketSearchPane = this.$contentContainer.find('.ticket_search_pane');
		this.$endCallNote = $('#end_call_notes');
		this.$requesterNameContainer = this.$endCall.find('.requester_name_container');
		this.$requesterName = this.$requesterNameContainer.find("#requesterName");
		this.$requesterEmail = this.$requesterNameContainer.find("#requesterEmail");
		this.$requesterEmailDom = this.$requesterNameContainer.find("#requesterEmail_dom");	
		this.$ticketSubject = this.$endCall.find("#ticketSubject");
		this.$requesterTicketSearch = this.$endCall.find('.end_call_ticket_search');
		this.$callNote = $('#call_notes');
		
		this.freshdialogOption = {
			backdrop: "static",
			height: "480px",
			keyboard: true,
			showClose: true,
			targetId: "#end_call",
			templateFooter: "",
			title: "Convert to ticket",
			toggle: "popupbox",
			width: "480px",
			classes: 'persistent_modal'
		};
		this.init();
		var self = this;
		
		// Ticket Search
		self.$endCallAddToExistingButton.bind('click', function (ev) {
			ev.preventDefault();

			self.$endCallMainContent.hide();
			self.$ticketSearchPane.show();
		});

		self.$ticketSearchPane.find('.back').bind('click', function (ev) {
			ev.preventDefault();

			self.$ticketSearchPane.hide();
			self.$endCallMainContent.show();
		});
		
		self.$endCallNewTicketDetailsForm.find('.back, .cancel').bind('click', function (ev) {
			ev.preventDefault();
			self.$requesterName.select2('data',null);
			self.$endCallNewTicketDetailsForm.hide();
			self.$endCallMainContent.show();
		});
		
		
		self.$endCallShowSaveTicketFormButton.bind('click', function () {
			self.$endCallMainContent.hide();
			self.$endCallNewTicketDetailsForm.show();
			self.initRequesterValue();

		});
		// Requeser Field in new ticket form -- end call form
		self.$requesterName.select2({
			placeholder: 'Requester',
			minimumInputLength: 1,
			multiple: false,
			ajax: {
				url: freshfone.requester_autocomplete_path,
				quietMillis: 1000,
				data: function (term) { 
					return {
						q: term
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

				return "<b>"+ result.value + "</b><br><span class='select2_list_detail'>" + 
								(userDetails) + "</span>"; 
			},
			formatSelection: function (result) {
				self.$requesterEmailDom.toggle(!result.id);
				self.$requesterEmail.val(result.email);
				self.$requesterName.data("requester_id",result.id);
				self.$requesterName.val(result.value);
				return result.value;
			}
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

			self.saveToExisting();
		});

		// Cancel or don't save
		self.$endCall.find('.end_call_cancel').click(function (ev) {
			ev.preventDefault();

			self.hideEndCallForm();
		});

		$(document).on('hide', '#end_call', function (ev) {
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
			this.saveTicket(false);
			this.hideEndCallForm();
		},
		
		saveToExisting: function () {
			this.saveTicket(true);
			this.hideEndCallForm();
		},
		resetDefaults: function () {
			if (this.inCall) {
				this.freshfoneuser.resetStatusAfterCall();
				if (!this.convertedToTicket) { this.freshfoneuser.updatePresence(); }

				this.freshfoneuser.bridgeQueuedCalls();
				this.freshfonewidget.resetToDefaultState();
				this.freshfonecalls.init();
				this.freshfoneuser.init();
			}
			this.$requesterName.select2('data',null);
			this.init();
		},
		
		saveTicket: function (is_ticket) {
			this.convertedToTicket = true;
			this.ticket_notes = this.$endCallNote.val();

			if (this.inCall) { this.getParams(); }
			is_ticket ? this.createTicket() : this.createNote();
		},
		getParams: function () {
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
					'direct_dial_number': this.directDialNumber
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
					'call_history': !this.inCall
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
			
			if (this.inCall) { this.$endCallNote.focus(); this.copyCallNotes(); }
			var callerId = (this.inCall) ? this.freshfonecalls.callerId : this.callerId;
			this.number = this.number || this.freshfonecalls.number;
			this.callerName = this.callerName || this.freshfonecalls.callerName;
			this.prefillForm();
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
			if (!$('#end_call').data('modal')) { $.freshdialog(this.freshdialogOption); }
			$('#end_call').modal('hide');
		},
		initRequesterValue: function () {
			this.$requesterName.removeData('requester_id');
			var initData = this.$requesterName.val(),self = this;
				if(initData.blank()) { return;}
				$.ajax({
				url: freshfone.requester_autocomplete_path,
				quietMillis: 1000,
				data: {q: initData},
				}).done(function(data) {
					self.$requesterName.select2("data",data.results[0]);
				});
		}
	};
}(jQuery));