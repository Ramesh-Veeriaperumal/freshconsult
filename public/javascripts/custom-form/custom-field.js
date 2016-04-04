(function($) {
	window.CustomField = function(element, options) {
		this.element = element;

		var defaults = {
			currentData : {
				disabled_customer_data: {
					'required_for_agent': false,
					'visible_in_portal': false,
					'editable_in_portal': false,
					'editable_in_signup': false,
					'required_in_portal': false,
					'required_for_closure': false
				},
				is_editable: 			true
			},
			fieldTemplate : {
				type:                   "text",
				dom_type:               "text",
				label:                  'Untitled',
				field_type:             "custom",
				required_for_agent:     false,
				id:                     null, 
				admin_choices:          [],
				field_options:      	{},
				action:                 "create", // delete || update || create
				is_editable:  			true, 
				disabled_customer_data: {
					'required_for_agent': false,
					'visible_in_portal': false,
					'editable_in_portal': false,
					'editable_in_signup': false,
					'required_in_portal': false,
					'required_for_closure': false
				}
			}, 
			fieldMap : {
				// key of dialogDomMap & fieldTemplate: [name_in_dom,"access prop"]
				field_type : ["custom-type", "value"],
				label : ["custom-label", "value"],
				label_in_portal : ["custom-label-in-portal", "value"],
				required_for_agent : ["agent-required", "checked"],
				visible_in_portal : ["customer-visible", "checked"],
				editable_in_portal : ["customer-editable", "checked"],
				editable_in_signup : ["customer-edit-signup", "checked"],
				required_in_portal : ["customer-required", "checked"],
				validate_using_regex : ["custom-regex-required", "checked"],
				field_options: ["custom-reg-exp", "value"],
				required_for_closure: ["agentclosure", "checked"],
				portalcc: ["portalcc", "checked"],
				portalcc_to: ["portalcc_to", "checked"],
				admin_choices : ["custom-choices", "function"]
			},
			labelDom: 						' input[name="custom-label"]', 
			regexDom: 						' input[name="custom-regex-required"]', 
			portalDom:  					' input[name="portalcc"]', 				
			fieldLabel: 					'.field-label',
			nestedConfig: 					'#customNestedConfig',
			customerCCOptions: 				'#cc_to_option', 
			dialogContainer: 				'#CustomFieldsPropsDialog'
		}
		this.dialogDOMMap = {};
		this.settings = $.extend(true, {}, defaults, options);
		this.initialize();
		return this;
	}
	CustomField.prototype = {
		initialize: function() {
			$.each(this.settings.fieldMap, $.proxy(function(key, value) {
				if(key == 'admin_choices') 
					this.dialogDOMMap[key] = $(this.settings.dialogContainer+" div[name='"+ value[0] + "']");
				else
					this.dialogDOMMap[key] = $(this.settings.dialogContainer + " input[name|='" + value[0] + "']");
			}, this) );
		},
		getProperties: function() {
			if($(this.element).data('fresh')) {
				var freshField = this.settings.fieldTemplate;
					freshField.field_type  = $(this.element).data('field-type');
					freshField.dom_type    = $(this.element).data('type');
		 
				this.settings.currentData = $.extend({}, freshField);
			}
			return this.settings.currentData;
		},
		setProperties: function() {
			this.initialize();

			this.settings.currentData = $H(this.settings.currentData);
			var field_type = this.dialogDOMMap['field_type'].val();

			$.each(this.settings.fieldMap, $.proxy(function(key, value) {
				if(!(key in this.settings.fieldTemplate)) {
					return;
				}
				if(key == 'admin_choices') {
					this.settings.currentData.set(key, this.getAllChoices(this.dialogDOMMap[key]));
				}
				// TODO: Discuss - separate class for Regex
				else if(key=='field_options') {
					this.setFieldOptions(key, value);
				}
				else if(key != 'field_type') {
					var val = this.dialogDOMMap[key].prop(value[1]);
					if((key == 'label' || key == 'label_in_portal') && val !== undefined) {
						val = escapeHtml(val);
					}
					this.settings.currentData.set(key, val);							
				}

			},this) );
			this.setAction(this.settings.currentData, "update");
			this.settings.currentData = this.settings.currentData.toObject();
			return this.settings.currentData;
		},
		setAction: function(obj, action){
			switch(action){
				case "update":
					if(obj.get('action') != "create") obj.set('action', action);
				break;
				default: 
					obj.set('action', action);
				break;
			}
		},
		getAllChoices: function(dom) {
			return [];
		},
		setFieldOptions: function(key, value) {
			var field_type = this.dialogDOMMap['field_type'].val(),
					fieldOptions = {};

			if(field_type == 'custom_text') {
				regexParts = [];

				if(this.dialogDOMMap['validate_using_regex'].prop('checked')) {
					fieldOptions['regex'] = {};
					regexParts = this.dialogDOMMap[key]
									.prop(value[1])
									.match(new RegExp('^/(.*?)/([gimy]*)$'));

					if(regexParts && regexParts.length > 0) {
						fieldOptions['regex']['pattern'] = escapeHtml(regexParts[1]);
						fieldOptions['regex']['modifier'] = regexParts[2];	
					}
				}
			}
			else if(field_type == 'default_requester') {
				fieldOptions['portalcc'] = this.dialogDOMMap['portalcc'].prop("checked");
				fieldOptions['portalcc_to'] = this.dialogDOMMap['portalcc_to'].filter(':checked').val();
			}
			this.settings.currentData.set(key, fieldOptions);
		},
		getValidationRules: function() {
			this.initialize();
			return {
				rules: {
					"custom-label": {
						"required": true
					},
					"custom-label-in-portal": {
						"required": {
							depends: $.proxy(function(element) {
								return this.dialogDOMMap['visible_in_portal'].prop('checked');
							}, this)
						}
					},
					"custom-reg-exp": {
						"required": {
							depends: $.proxy(function(element) {
								return this.dialogDOMMap['validate_using_regex'].prop('checked');
							}, this)
						},
						"validate_regexp": {
							depends: $.proxy(function(element) {
								return this.dialogDOMMap['validate_using_regex'].prop('checked');
							}, this)
						}
					}
				}
			}; 
		},
		toggleRegexValidation: function(checkbox) {
			$(checkbox).parents('fieldset').next().toggle(checkbox.checked);
		},
		toggleCustomerBehaviorOptions: function(checkbox){ 
			var next_ele=$(this.settings.dialogContainer)
							.find('[data-nested-value='+checkbox.getAttribute("toggle_ele")+']');
			if(checkbox.checked && !next_ele.data('disabledByDefault')){
				next_ele
					.children("label")
					.removeClass("disabled")
					.children("input:checkbox")
					.attr("disabled", false);
			}else{
				next_ele
					.find("label")
					.addClass("disabled")
					.children("input:checkbox")
					.prop("checked", false)
					.prop("disabled", true);
			}
		},
		togglePortalOptions: function(checkbox) {
			$(this.settings.customerCCOptions).toggle(checkbox.checked);
		},
		attachEvents: function() {
			$(document).on('click.dialog-events', '.delete-field', $.proxy(function(e) {
				$(this.element).find('.delete-field').trigger('click');
				return false;
			}, this) );

			$(document).live("change.dialog-events", this.settings.nestedConfig + " input:checkbox", $.proxy(function(e){
				this.toggleCustomerBehaviorOptions(e.target);
				return false;
			}, this) );

			$(document).on("change.dialog-events", this.settings.dialogContainer + this.settings.regexDom, $.proxy(function(e){
				e.stopPropagation();
				this.toggleRegexValidation(e.target);
				return false;
			}, this) );

			$(document).on("change.dialog-events", this.settings.dialogContainer + this.settings.portalDom, $.proxy(function(e){
				e.stopPropagation();
				this.togglePortalOptions(e.target);
				return false;
			}, this) );

			$(document).on("keyup.dialog-events", this.settings.dialogContainer + this.settings.labelDom, $.proxy(function(e){
				$(this.settings.fieldLabel).text($(e.target).val());
				return false;
			}, this) );
		},
	};
})(window.jQuery);