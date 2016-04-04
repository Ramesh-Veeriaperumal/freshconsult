(function($) {
	window.TicketFieldsForm = function(options) {
		customFieldsForm.call(this, options);
		return this;
	}
	TicketFieldsForm.prototype = {
		deletePostData: function(data) {
			data = customFieldsForm.prototype.deletePostData.call(this, data);
			data.choices = data.custom_field_choices_attributes || [];
			delete data.custom_field_choices_attributes;

			$.each(data.choices, function(index, item) {
				if(data.field_type == 'default_status') {
					item.status_id = item.id;
					item.deleted = (item._destroy) ? true : false;
					item.name = item.value;
					delete item.value;
					delete item._destroy;
					delete item.id;
					delete item.field_type;
				}
				else {
					delete item.name;
				}
			});


			if(data.action == 'update') {
				data.action = 'edit';
			}


			delete data.portalcc;
      delete data.portalcc_to;
      delete data.dom_type;
      delete data.level_three_present;
      data.required = data.required_for_agent;
      delete data.required_for_agent;
      delete data.name;
      if(data.field_type == 'default_ticket_type' || data.field_type == 'custom_dropdown' ) {
      	data.picklist_values_attributes = data.choices;
      }
			return data;
		}	
	}
	TicketFieldsForm.prototype = $.extend({}, customFieldsForm.prototype, TicketFieldsForm.prototype);
	$(document).ready(function(){
		$.each(customFields, function(index, item){
			item.admin_choices = item.admin_choices || item.choices || [];
			var choices = [];
			$.each(item.admin_choices, function(idx, itm) {
				var temp = {};
				if($.isArray(itm) && item.field_type != 'nested_field') {
					temp.name = itm[0];
					temp.id = itm[2] || itm[1];
					temp._destroy = itm.deleted || false;
					temp.value = temp.name
				}
				else {
					temp = $.extend({}, temp, itm);
					temp.id = temp.status_id;
					temp._destroy = temp.deleted || false;
					temp.value = temp.name;
				}
				choices.push(temp);
			})
			if(item.field_type != 'nested_field') {
				item.admin_choices = choices;
			}
			// item.picklist_values_attributes = item.admin_choices;
			item.required_for_agent = item.required;
		})
		ticketField = new TicketFieldsForm({existingFields: customFields,
											customMessages: tf_lang,
											customFormType: 'ticket',
											customSection: customSection
										});
		ticketField.initialize();
	});
})(jQuery);