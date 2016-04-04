(function($) {
	window.ContactFieldsForm = function(options) {
		customFieldsForm.call(this, options);
		return this;
	}
	ContactFieldsForm.prototype = {
	}
	ContactFieldsForm.prototype = $.extend({}, customFieldsForm.prototype, ContactFieldsForm.prototype);

	$(document).ready(function(){
		var customField = new ContactFieldsForm({existingFields : customFields, 
						customMessages: tf_lang,
						nonEditableFields: ['default_tag_names', 'default_description', 'default_client_manager'],
						disabledByDefault: {
								'default_company_name' : 
									  {
										'visible_in_portal' : false,
										'editable_in_portal' : true,
										'editable_in_signup' : true,
										'required_in_portal' : true                         
									  }
						},
						customFormType: 'contact'
					  });
		customField.initialize();
		// Show ProfilePic Holder
		jQuery('.profile-pic-placeholder img').removeClass('hide');
	});
})(jQuery);