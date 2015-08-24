/*jslint browser: true, devel: true */
/*global  App */

window.App = window.App || {};
window.App.Tickets = window.App.Tickets || {};
(function ($) {
	"use strict";
	
	 App.Tickets.Compose = {
    current_module: '',

    onVisit: function (data) {
      invokeRedactor('helpdesk_ticket_ticket_body_attributes_description_html', 'ticket');
      this.setDefaultVals();
      this.bindSave();
      this.bindTypeChange();
      jQuery.validator.messages.requester = "Please add a valid requester";
      jQuery("#helpdesk_ticket_email_config_id").trigger('change');
      jQuery('#helpdesk_ticket_status').trigger("change");
    },

    setDefaultVals: function () {
      jQuery('.default_agent, .default_source, .default_product').hide();
      jQuery('#helpdesk_ticket_source').val(10);
      jQuery('#helpdesk_ticket_status').val(5);
      jQuery('input.requester').focus();
      jQuery("#helpdesk_ticket_product_id").removeClass("required");
      jQuery("#helpdesk_ticket_responder_id").removeClass("required");
      jQuery("#helpdesk_ticket_product_id").removeClass("required_closure");
      jQuery("#helpdesk_ticket_responder_id").removeClass("required_closure");

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
      
      $("#ComposeTicket select.dropdown, #ComposeTicket select.dropdown_blank, #ComposeTicket select.nested_field").livequery(function(){
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

      $('#ComposeTicket #helpdesk_ticket_tags [rel=tagger]').livequery(function() {
        var hash_val = []
        $(this).select2({
          multiple: true,
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
      });
    },

    bindSave: function () {
      $('body').on('click.compose', '#compose_and_new', function (ev) {
      preventDefault(ev);
      var _form = jQuery(this).parents("form");
      _form.append(new Element('input', {
                     type: 'hidden',
                     name: 'save_and_compose',
                     value: true
                   }));
      _form.submit();
      });

      jQuery('#ComposeTicket').bind("submit", function(){
        var _form = jQuery(this);
        if(_form.valid()) {
          _form.find("button, a.btn").attr('disabled',true);
        }
      });

    },

    bindTypeChange: function () {
      $('body').on('change.compose', "#helpdesk_ticket_ticket_type", function(e){
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
    },

		onLeave: function (data) {
      $('body').off('.compose');
      jQuery.validator.messages.requester = window.App.Tickets.Compose.original_requester_error_message;
		}
	};
}(jQuery));
