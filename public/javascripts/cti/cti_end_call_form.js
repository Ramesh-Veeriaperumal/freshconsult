var CtiEndCall;
(function ($) {
	"use strict";
	CtiEndCall = function () {
		this.$widget = $('.cti_widget');
		this.$contentContainer = $('.cti_content_container');
		this.$endCall = this.$contentContainer.find('#cti_end_call');
		this.$endCallAddToExistingButton = this.$endCall.find('.save_to_existing');
		this.$endCallMainContent = this.$endCall.find('.main_content');
		this.$endCallTicketSearch = this.$endCall.find('.integration-ticket-search');
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
		this.$requesterTicketSearch = this.$endCall.find('.integration-ticket-search');
		this.$callNote = $('#call_notes');
		this.recordingUrl = "";
		this.isNotePrivate = false;
		this.freshdialogOption = {
			backdrop: "static",
			height: "480px",
			keyboard: true,
			showClose: true,
			targetId: "#cti_end_call",
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
				url: '/freshfone/autocomplete/requester_search',
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
				if(userDetails && $(userDetails).trim != "") {
					userDetails = "(" + userDetails + ")";
				} else {
					if (!result.id) { userDetails = "New requester";}
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

		$(document).on('hide', '#cti_end_call', function (ev) {
			//self.resetDefaults();
		});
	};
	
	CtiEndCall.prototype = {
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
			this.resetForm();
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
			this.init();
		},
		
		saveTicket: function (is_ticket) {
			this.convertedToTicket = true;
			this.ticket_notes = this.$endCallNote.val();
			is_ticket ? this.createTicket() : this.createNote();
		},
		
		createTicket: function () {
			var json_data={"ticket":{
				"email":this.requesterEmail(),//"sample@example.com",
				"description":this.ticket_notes,
				"subject":this.ticketSubject(),
				"requester_name": this.requesterName(),
				"number" : this.number,
				"recordingUrl" : this.recordingUrl
			}};
			$.ajax({
				type: 'POST',
				url: '/integrations/cti/customer_details/create_ticket',
				contentType: 'application/json',
				data: JSON.stringify(json_data)
			});
		},
		createNote: function () {
			if (this.ticketId === undefined) { return false; }
			var json_data={
						  "ticketId" : this.ticketId,
						  "msg" : this.ticket_notes,
						  "recordingUrl" : this.recordingUrl
						};
			$.ajax({
				type: 'POST',
				url: '/integrations/cti/customer_details/create_note',
				contentType: 'application/json',
				data: JSON.stringify(json_data)
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
			this.$requesterEmailDom.hide();
			this.$requesterName.select2('data',null);
		},
		showEndCallForm: function () {
			if (!$('#cti_end_call').data('modal')) { $.freshdialog(this.freshdialogOption); }
			$('#cti_end_call').modal('show');
			 this.prefillForm();
		},
		prefillForm: function () {
			this.resetForm();
			this.$ticketSubject.val(this.generateTicketSubject());
			this.$requesterName.val(this.number);
			this.$requesterTicketSearch.initializeRequester(this.callerName);
		},
		generateTicketSubject: function () {
			return 'Call with ' +  "(" + this.formattedNumber() + ")" +
						' on ' + Date().toString('ddd, MMM d @ h:mm:ss tt').replace(/\@/, 'at');
		},
		formattedNumber: function () {
			if(this.callerName) return this.callerName;
			else return this.number;
		},
		callerLocation: function () {
			
		},
		hideEndCallForm: function () {
			if (!$('#cti_end_call').data('modal')) { $.freshdialog(this.freshdialogOption); }
			$('#cti_end_call').modal('hide');
		},
		initRequesterValue: function () {
			var initData = this.$requesterName.val(),self = this;
				if(initData.blank()) { return;}
				$.ajax({
				url: '/freshfone/autocomplete/requester_search',
				quietMillis: 1000,
				data: {q: initData},
				}).done(function(data) {
					self.$requesterName.select2("data",data.results[0]);
				});
		}
	};
}(jQuery));