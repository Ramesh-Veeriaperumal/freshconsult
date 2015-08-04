(function($) {
	window.CompanyFieldsForm = function(options) {
		customFieldsForm.call(this, options);
		return this;
	}
	CompanyFieldsForm.prototype = {
	}
	CompanyFieldsForm.prototype = $.extend({}, customFieldsForm.prototype, CompanyFieldsForm.prototype);

	$(document).ready(function(){
		var customField = new CompanyFieldsForm({existingFields : customFields, 
						customMessages: tf_lang,
						disabledByDefault: {
								'default_name' : 
									  {
										'required_for_agent' : true                         
									  }
						},
						customFormType: 'company'
					  });
		customField.initialize();
	});
})(jQuery);