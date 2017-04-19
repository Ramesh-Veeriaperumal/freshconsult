
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
		var saveAndCreate = false;

		this.$body.on('click.newTicket', '#newticket-submit', function(){
			var trial_spam_error_msg = jQuery("#trial_spam_error_msg").val();
			var to_cc_spam_threshold = JSON.parse(jQuery("#to_cc_spam_threshold").val());
			var is_trial_spam_account = JSON.parse(jQuery("#is_trial_spam_account").val());

			if(is_trial_spam_account && !App.Tickets.LimitEmails.limitComposeEmail(jQuery('#NewTicket'), '.cc-address', to_cc_spam_threshold, trial_spam_error_msg)) {
	    		if(!jQuery('.cc-address').is(':visible')) {
	    			jQuery("[data-action='show-cc']").click();
	    		}
	          	return false
	        }

	        jQuery(".cc-address .cc-error-message").remove();
			jQuery("#NewTicket").submit();
		});
		// This form Submit should be bind at last. Then only the pjax_form_submit will work correct.
		// The workaround for binding the .on('submit') befor this event capture use .bindFirst('submit').


		this.$createForm.on('submit.newTicket', function(ev){
			var _form = jQuery("#NewTicket");
			//check for childrens added from apply template action
			if(jQuery('#child_select_template_wrapper .tree').length > 0){
				CreateTicket.includeChildTemplates(_form);
			}

			if(_form.valid()){
				if (_form.find('input[name="cc_emails[]"]').length >= 50) {
					alert('You can add upto 50 CC emails');
					return false;
				}
				if(!saveAndCreate){
					jQuery("#newticket-submit").text(jQuery("#newticket-submit").data('loading-text')).attr('disabled', true);
				}else{
					saveAndCreate = false;
					jQuery(".save_and_create_child").text(jQuery(".save_and_create_child").data('loading-text')).attr('disabled', true);
					jQuery(".save_and_create_child").next().attr('disabled', true);
				}

				jQuery("#newticket-submit").next().attr('disabled', true);
				jQuery(".save_and_create_child").attr('disabled', true);
				jQuery(".cancel-btn").attr('disabled', true);

			} else {
				ev.preventDefault();
				return false;
			}

			pjax_form_submit("#NewTicket", ev);

		}.bind(this));

		this.$body.on('click.newTicket', 'a[name="action_save"]', function(ev){
				preventDefault(ev);
				if(jQuery(this).data('trigger') == "add_child"){
					saveAndCreate = true;
				}
				var _form = jQuery("#NewTicket");
				if(jQuery('#child_select_template_wrapper .tree').length > 0){
					CreateTicket.includeChildTemplates(_form);
				}
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
	includeChildTemplates: function(form){
		var child_ids = [];
      	jQuery('.child_template_items.active').each(function(){
	        var id = jQuery(this).data('template-id');
	        child_ids.push(id);
      	});

      	if(child_ids.length > 0){
      		form.append(new Element('input', {
				type: 'hidden',
				name: 'parent_templ_id',
				value: jQuery('#child_select_template_wrapper .parent_id_holder').data('parent-template-id')
			}));

			form.append(new Element('input', {
				type: 'hidden',
				name: 'child_ids',
				value: child_ids
			}));
      	}
	},
	createHiddenElement: function(fieldName, val, appendForm){
		jQuery('<input>').attr({
			type: 'hidden',
			value: val,
			name: fieldName
		}).appendTo(appendForm);
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
		this.$dynamicSections = this.$el.find('.dynamic_sections');
	},

	bindEvents: function(){
		this.groupToAgent();
		this.validateAttachment();
		this.dynamicSections();
		this.requesterToCompany();
	},

	unBindEvents: function(){
		this.$el.off('.ticketForms');
		this.$groupselector.off('.ticketForms');
		this.$dynamicSections.off('.ticketForms');
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
					type: 'POST',
					data: {email: ticket_email},
					datatype: 'json',
					url: $companyurl,
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

	dynamicSections: function(){
		this.$dynamicSections.on("change.ticketForms", function(){
			var id;
			var $el = jQuery(this);
			selected = $el.find(':selected');
			if (selected.length > 0) id = selected.data().id;
			nextElement = $el.closest('li').next();
			nextElement.find('ul.ticket_section').remove();
			var element = jQuery('#picklist_section_'+id).parent();
			if(element.length != 0) {
				element.append(jQuery('#picklist_section_'+id).val()
				.replace(new RegExp('&lt', 'g'), '<')
				.replace(new RegExp('&gt', 'g'), '>'));
			}
		}).trigger("change");
	}

}
