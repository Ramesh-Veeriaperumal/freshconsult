
window.App = window.App || {};
window.App.Tickets = window.App.Tickets || {};

(function ($) {
	"use strict";

	App.Tickets.Create = {

		onFirstVisit: function (data) {
			this.onVisit(data);
		},
		onVisit: function (data) {
			CreateTicket.init();
		},
		onLeave: function (data) {
			CreateTicket.unBindEvents();
		}
	};
}(window.jQuery));


var CreateTicket = {

	init: function(){
		this.cacheDOM();
		this.bindEvents();
		invokeRedactor('helpdesk_ticket_ticket_body_attributes_description_html', 'ticket');
		TicketTemplate.init();
		TicketForm.init();
		AutoSuggest.requester();
		AutoSuggest.cc();
	},

	cacheDOM: function(){
		this.$el = jQuery("#ticket-fields-wrapper");
		this.$createForm = this.$el.find('#NewTicket');
		this.$body = jQuery('body');
	},

	unBindEvents: function(){
		this.$el.off('.newTicket');
		this.$createForm.off('.newTicket');
		this.$body.off('.newTicket');
		TicketForm.unBindEvents();
		TicketTemplate.destroy();
	},

	bindEvents: function(){
		this.$body.on('click.newTicket', '#newticket-submit', function(){
			jQuery("#NewTicket").submit();
		});

		this.$createForm.on('submit.newTicket', function(){
			var _form = jQuery("#NewTicket");
			var topic_id = jQuery("#topic_id_stub").val();
			if(_form.valid()){
				if (_form.find('input[name="cc_emails[]"]').length >= 50) {
					alert('You can add upto 50 CC emails');
					return false;
				}
				if(topic_id){
						this.createHiddenElement('topic_id', topic_id, _form);
				}
				jQuery("#newticket-submit").text(jQuery("#newticket-submit").data('loading-text')).attr('disabled', true);
				jQuery("#newticket-submit").next().attr('disabled', true);
				jQuery(".cancel-btn").attr('disabled', true);
			}
		}.bind(this));

		this.$body.on('click.newTicket', 'a[name="action_save"]', function(ev){
				preventDefault(ev);
				var _form = jQuery("#NewTicket");
				if(jQuery(this).prop('id') == 'save_and_close') {
					jQuery('#helpdesk_ticket_status').val(TICKET_STATUS.CLOSED);
					jQuery('#helpdesk_ticket_status').trigger('change');
				}
				else {
					_form.append(new Element('input', {
						type: 'hidden',
						name: 'save_and_create',
						value: true
					}));
				}
				_form.submit();
			});

			this.$body.on('click.newTicket', 'a[rel="ticket_canned_response"]', function(ev){
				ev.preventDefault();
    		  	jQuery("#canned_response_show").attr('data-tiny-mce-id', "#helpdesk_ticket_ticket_body_attributes_description_html");
				jQuery('#canned_response_show').trigger('click');
			});

			 this.$el.on("click.newTicket", "#add_requester_btn_proxy", function(ev){
	              ev.preventDefault();
	              jQuery('#add_requester_btn').trigger("click");
        	  });
	},
	createHiddenElement: function(fieldName, val, appendForm){
		jQuery('<input>').attr({
			type: 'hidden',
			value: val,
			name: fieldName
		}).appendTo(appendForm);
	},
	ticketFromForum: function(){
		var topic_id = jQuery("#topic_id_stub").val();

		if(topic_id){
			jQuery(".redactor_editor").html(jQuery("#topic_desc").val());
			jQuery("#helpdesk_ticket_subject").val(jQuery("#topic_title").val());
			jQuery("#helpdesk_ticket_email").val(jQuery("#topic_req").val());
		}else{
			jQuery(".redactor_editor").html("");
			jQuery("#helpdesk_ticket_subject").val("");
			jQuery("#helpdesk_ticket_email").val("");
		}
	}
}

var TicketForm = {
	init: function(){
		this.cacheDOM();
		this.$requester.focus(); // SHRIDHAR HAS COMMENTED OUT THIS LINE
		this.bindEvents();
	},

	cacheDOM: function(){
		this.$el = jQuery("#ticket-fields-wrapper");
		this.$requester = this.$el.find('input.requester');
		this.$groupselector = this.$el.find('#helpdesk_ticket_group_id');
		this.$agentselector = this.$el.find('#helpdesk_ticket_responder_id');
		this.$tagsholder = this.$el.find("#helpdesk_tags");
		this.$ticketType = this.$el.find("#helpdesk_ticket_ticket_type");
	},

	bindEvents: function(){
		this.groupToAgent();
		this.validateAttachment();
		this.ticketType();
		this.requesterToCompany();
	},

	unBindEvents: function(){
		this.$el.off('.ticketForms');
		this.$groupselector.off('.ticketForms');
		this.$ticketType.off('.ticketForms');
		this.$tagsholder.select2('destroy');
	},

	requesterToCompany: function(){
		var $requester_val= jQuery("#helpdesk_ticket_email").val(),
			$companyurl = jQuery("#companyurl").val();
		jQuery("#helpdesk_ticket_email").on("blur.ticketForms", function(){
			$requester_val = jQuery("input.requester").val();
		});
		jQuery("#helpdesk_ticket_email").on("focusout.ticketForms", function(){
			var re = /\<(.*)\>/i,
				validajax = false,
				ticket_email = jQuery("#helpdesk_ticket_email").val();
				ticket_email_match = ticket_email.match(re) ;

  			if (ticket_email_match != null) {
  				var rec = /^(([^<>()[\]\\.,;:\s@\"]+(\.[^<>()[\]\\.,;:\s@\"]+)*)|(\".+\"))@((\[[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\])|(([a-zA-Z\-0-9]+\.)+[a-zA-Z]{2,}))$/;
  				validajax = rec.test(ticket_email_match[1]);
  			}

			if(($requester_val != ticket_email) && validajax){
				jQuery.ajax({
					url: $companyurl+"?email="+ticket_email,
					success: function(data){
						if(data != false){
							jQuery('#helpdesk_ticket_company_id').empty();
							for(var i=0; i<data.length; i++){
								jQuery("<option/>").val(data[i][1]).html(data[i][0]).appendTo("#helpdesk_ticket_company_id");
							}
							jQuery('#helpdesk_ticket_company_id').trigger('change');
							jQuery('.default_company').insertAfter(jQuery(".default_requester")).show();
							jQuery('#helpdesk_ticket_company_id').removeAttr("disabled");
						}
						else{
							jQuery('.default_company').slideUp();
							jQuery('#helpdesk_ticket_company_id').attr("disabled", true);
						}
					}
				});
			}
			else if($requester_val != ticket_email){
			jQuery('.default_company').slideUp();
			jQuery('#helpdesk_ticket_company_id').attr("disabled", true);
			}
		});

		if(App.namespace === "helpdesk/tickets/edit" && (jQuery("#helpdesk_ticket_company_id").attr("disabled") != "disabled")){
			jQuery('.default_company').insertAfter(jQuery(".default_requester")).show();
		}
	},

	groupToAgent: function(){
		var _this = this;
		this.$groupselector.on("change.ticketForms", function(e){

			var prev_val = _this.$agentselector.val();
			_this.$agentselector.html("<option value=''>...</option>");

			var url = prev_val == "" ? '/helpdesk/commons/group_agents/'+this.value : '/helpdesk/commons/group_agents/'+this.value+"?agent="+prev_val;
			jQuery.get(url).done(function(data){
				_this.$agentselector.html(data).trigger('change');
			});

		}).trigger("change");
	},

	validateAttachment: function(){
		jQuery('.invalid_attachment a').livequery(function(){
			jQuery(this).text(jQuery(this).text().substring(0,19)+"...");
		});
	},

	ticketType: function(){
		this.$ticketType.on("change.ticketForms", function(){
			var id = jQuery(this).find(':selected').data().id;
			jQuery('ul.ticket_section').remove();
			var element = jQuery('#picklist_section_'+id).parent();
			if(element.length != 0) {
				element.append(jQuery('#picklist_section_'+id).val()
				.replace(new RegExp('&lt', 'g'), '<')
				.replace(new RegExp('&gt', 'g'), '>'));
			}
		}).trigger("change");
	}

}
