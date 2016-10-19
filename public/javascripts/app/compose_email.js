// Compose email cleanup code
//

var ComposeEmail = {
    init: function(){
      this.domCache();
      this.bindEvents();
      this.defaultSettings();
      this.appendSignature();
      invokeRedactor('helpdesk_ticket_ticket_body_attributes_description_html', 'ticket');
      ComposeAutoSuggest.cc();
      AutoSuggest.requester();
      TicketTemplate.init();
    },
    initEvents: function(){
      this.domCache();
      this.bindEvents();
      TicketTemplate.init();
      ComposeAutoSuggest.cc();
      AutoSuggest.requester();
    },
    domCache: function(){
    	this.$body = jQuery('body');
		this.$el = this.$body.find("#compose-new-email");
		this.$tag = this.$el.find("#helpdesk_tags");
		this.$fromaddress = this.$el.find("select.from_address_wrapper");
    },
    unbindEvents: function(){
    	this.$el.off('.compose');
    	jQuery('#ComposeTicket').off('.compose');
    	this.$body.off('.compose');
      TicketTemplate.destroy();
    },
    defaultSettings: function(){
      // Snippets moved from compose js
    jQuery('.default_agent, .default_source, .default_product').hide();
    //removing internal fileds in compose email for negating form validation
    //when these fields are set required in admin ticket fields
    jQuery('.default_internal_agent, .default_internal_group').remove();
    jQuery('#helpdesk_ticket_source').val(10);
    jQuery('#helpdesk_ticket_status').val(5);
    jQuery("#helpdesk_ticket_product_id").removeClass("required");
    jQuery("#helpdesk_ticket_responder_id").removeClass("required");
    jQuery("#helpdesk_ticket_product_id").removeClass("required_closure");
    jQuery("#helpdesk_ticket_responder_id").removeClass("required_closure");
    this.$fromaddress.select2({minimumResultsForSearch: 10});

    this.$fromaddress.on("select2-open.compose", function() {
      jQuery('body').addClass('compose-from-select2');
    });

    this.$fromaddress.on("select2-close.compose", function() {
      jQuery('body').removeClass('compose-from-select2');
    });

    },

    appendSignature: function(){
		signature = jQuery("#signature").val();
    	jQuery(".redactor_editor").html(signature);
    },
    
    bindEvents: function(){
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

		jQuery("#ComposeTicket select.dropdown, #ComposeTicket select.dropdown_blank, #ComposeTicket select.nested_field").livequery(function(){
			if (this.id == 'helpdesk_ticket_priority') {
				jQuery(this).select2({
					formatSelection: formatPriority,
					formatResult: formatPriority,
					escapeMarkup: escapePriority,
					specialFormatting: true,
					minimumResultsForSearch: 10
				});
			} else {
				jQuery(this).select2({
					minimumResultsForSearch: 10
				});
			}
		});

		this.$body.on('assetLoaded.fjax', function(){
			window.App.Tickets.Compose.original_requester_error_message = jQuery.validator.messages.requester;
		});

		this.$el.on('click.compose', "[data-action='show-cc']",function(){
			jQuery('.show-cc').addClass('muted');
			jQuery('.cc-address ').removeClass('hide');
			jQuery('.to-address').addClass('light-border');
		});

		this.$el.on('click.compose', "[data-action='hide-cc']", function(){
			jQuery('.show-cc').removeClass('muted');
			jQuery('.cc-address ').addClass('hide');
			jQuery('.to-address').removeClass('light-border');
		});

		var close_flash = jQuery("#compose-notice")
		closeableFlash(close_flash);

		jQuery('.invalid_attachment a').livequery(function(ev){
			jQuery(this).text(jQuery(this).text().substring(0,19)+"...");
		});

		this.$body.on('change.compose', "#helpdesk_ticket_ticket_type", function(e){
			var id = jQuery("option:selected", this).data("id");
			jQuery('ul.ticket_section').remove();
			var element = jQuery('#picklist_section_'+id).parent();
			if(element.length != 0) {
			element.append(jQuery('#picklist_section_'+id).val()
			.replace(new RegExp('&lt', 'g'), '<')
			.replace(new RegExp('&gt', 'g'), '>'));
			}
			jQuery('#helpdesk_ticket_status').trigger("change");
		});

		this.$body.on('click.compose', '#compose_and_new', function (ev) {
			preventDefault(ev);
			var _form = jQuery("#ComposeTicket");
			_form.append(new Element('input', {
				type: 'hidden',
				name: 'save_and_compose',
				value: true
			}));
			_form.trigger('submit.compose');
		});

		jQuery('#ComposeTicket').on("submit.compose", function(ev){
			preventDefault(ev);

			var _form = jQuery(this);
			if(_form.valid()) {
        jQuery("#compose-submit").text(  jQuery("#compose-submit").data('loading-text')).attr('disabled', true);
        jQuery("#compose-submit").next().attr('disabled', true);
        jQuery(".cancel-btn").attr('disabled', true);
				// _form.find("button, a.btn").attr('disabled',true);

				pjax_form_submit("#ComposeTicket");
			}

			return false;
		});

	    this.$body.on('click.compose', '#compose-submit', function(ev){
	    	var cc_email = jQuery('#compose-new-email');
	    	var ele = jQuery('.cc-address'),
	    		limit = ele.data('limit'),
	    		is_trial = ele.data('isTrial'),
	    		msg = ele.data('msg');


	    	if(is_trial && !App.Tickets.LimitEmails.limitComposeEmail(jQuery('#compose-new-email'), '.cc-address', limit, msg)) {

	    		if(!jQuery('.cc-address').is(':visible')) {
	    			jQuery("[data-action='show-cc']").click();
	    		}
	          	return false
	        }

	        jQuery(".cc-address .cc-error-message").remove();
	        jQuery("#ComposeTicket").trigger('submit.compose');
	    });

		this.$body.on('click.compose', 'a[rel="ticket_canned_response"]', function(ev){
				ev.preventDefault();
    		  	jQuery("#canned_response_show").attr('data-tiny-mce-id', "#helpdesk_ticket_ticket_body_attributes_description_html");
				jQuery('#canned_response_show').trigger('click');
		});
    }
};


var ComposeAutoSuggest = {
	cc: function(){
		var meta = jQuery("#compose-meta").data();
		function lookup(searchString, callback) {
		new Ajax.Request(meta.req+'?q='+encodeURIComponent(searchString), {
			method : "GET",
			onSuccess: function(response) {
			var choices = $A();
			response.responseJSON.results.each(function(item){
				if(item.value == "") {
					choices.push([item.details, item.details]);
				} else {
					choices.push([item.details , item.details ]);
				}
			});
		callback(choices);
	} });
	}
	var cachedBackend = new Autocompleter.Cache(lookup, {searchKey: 0, choices: 10});
	var cachedLookup = cachedBackend.lookup.bind(cachedBackend);
	if(meta.isagent){
		 new Autocompleter.MultiValue("cc_emails", cachedLookup,
	        							  $A(),{frequency: 0.1,
	        							  acceptNewValues: true,separatorRegEx:/;|,/});
	}

	}

}
