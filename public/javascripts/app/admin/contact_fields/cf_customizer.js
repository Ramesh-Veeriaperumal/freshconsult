!(function($){
	window.CustomFields = function(options) {
		var defaults = {
			existingFields : {},
			currentField : null,
			currentData : null,
			customFieldsWrapper : '#custom-fields',
			customFieldItem: '#custom-fields li',
			dialogContainer : '#CustomFieldsPropsDialog',
			formContainer : '#custom-field-form',
			clonedFormContainer : '#cloned-custom-field-form',
			fieldValues : '#field_values',
			dropdownChoiceDiv : '.custom-choices',
			customPropertiesDiv : '#CustomProperties',
			propsSubmitBtn: '#PropsSubmitBtn',
			customPropsModal : '#CustomPropsModal',
			nestedConfig : '#customNestedConfig',
			saveBtn : '.save-custom-form',
			cancelBtn : '#cancel-btn',
			submitForm : '#Updateform',
			addChoice : '#addchoice',
			deleteChoice : '.delete-choice',
			privateSymbol : '.private-symbol',
			fieldLabel: '.field-label',
			customMessages : {
				untitled : 'Untitled',
				firstChoice : 'One',
				secondChoice : 'Two', 
				noChoiceMessage : 'No Choice',
				confirmDelete : 'Are you sure you want to delete this?'
			},
			validateOptions: {},
			nonEditableFields: [],
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
				choices : ["custom-choices", "function"]
			},
			disabledByDefault: [],
			customFieldType: '', 
			maxNoOfChoices: '50',
			disabledCustomerDataTemplate: {
				'visible_in_portal': false,
				'editable_in_portal': false,
				'editable_in_signup': false,
				'required_in_portal': false
			}
		};

		this.settings = $.extend({}, defaults, options);
		this.dialogDOMMap = {};
		this.fieldTemplate = $H({
			type:                   "text",
			dom_type:               "text",
			label:                  this.settings.customMessages.untitled,
			label_in_portal:        "", 
			field_type:             "custom",
			required_for_agent:     false,
			visible_in_portal:      true, 
			editable_in_portal:     true, 
			editable_in_signup:     false, 
			required_in_portal:     false,
			id:                     null, 
			choices:                [],
			field_options: 			{},
			action:                 "create" // delete || update || create
 		});
	};

	CustomFields.prototype = {
		feedJsonForm: function(formInput){
			var self = this;
			$(formInput).each(function(index, dataItem){
				var dom = self.constructFieldDom(dataItem);
				$(self.settings.formContainer).append(dom);  
			});
		},
		constructFieldDom: function(dataItem, container) {
			var fieldContainer = container || jQuery('<li/>');
			var controlLabel = jQuery("<div class='control-label'/>");
			var label = jQuery("<label class='custom-form-label'/>").append(dataItem.label);
			var lock = jQuery("<span />").addClass('ficon-security private-symbol muted');
			label.prepend(lock);
			controlLabel.append(label);
			var field = jQuery("<div class='controls'/>");
			var controlGroup = jQuery('<div class="control-group"/>');
			// For options like edit & delete
			var optionsWrapper = jQuery("<div />").addClass('options-wrapper').append("<div class='opt-inner-wrap'/>");
			var fieldAttr = '';

			fieldContainer.empty()
						.removeClass('field')
						.addClass('custom-field');

			switch(dataItem.dom_type) {
				case 'dropdown_blank':
					dataItem.type = "dropdown";
					break;
				default:
					dataItem.type = dataItem.dom_type;
			}
			switch(dataItem.dom_type) {     
				case 'text':
				case 'phone_number':
				case 'url':
				case 'number':
				case 'email':
					field.append('<input type="text" disabled/>');
					controlGroup.append(controlLabel);
					break;
				case 'date':
					field.append('<input type="text" disabled/>');
					field.append('<span class="ficon-date"></span>');
					controlGroup.append(controlLabel).addClass('date');
					break;
				case 'checkbox':               
					field.append('<input type="checkbox" disabled/>' + '<span>'+dataItem.label+'</span>' );
					fieldContainer.addClass('checkbox-wrap');
					break;
				case 'time_zone_dropdown':
				case 'dropdown':
				case 'dropdown_blank':  
					dataItem.dom_type = 'dropdown_blank';
					$(dataItem.choices).each(function(ci, choice){
						field.append("<option " + choice[1] + ">" + choice[0] + "</option>");
					});
					field.wrapInner("<select class='select2' disabled/>");
					controlGroup.append(controlLabel);
					break;
				case 'paragraph':
				case 'description':
					field.append('<textarea rows="5" disabled></textarea>');
					controlGroup.append(controlLabel);
					break;
			}

			var editField = jQuery('<div class = "ficon-edit edit-field options"/>');
			optionsWrapper.find('.opt-inner-wrap').append(editField);
			optionsWrapper.find('.opt-inner-wrap').append('<div class = "ficon-trash-o delete-field options"/>');
			controlGroup.prepend(optionsWrapper);
			controlGroup.append(field);

			$(field).prepend("<span class='overlay-field' />");         
			if(this.settings.disabledByDefault[dataItem.field_type]) {
				dataItem['disabled_customer_data'] = this.settings.disabledByDefault[dataItem.field_type];
			}
			else {
				dataItem['disabled_customer_data'] = this.settings.disabledCustomerDataTemplate;
			}
			fieldContainer.data("raw", dataItem);
			fieldContainer.addClass(dataItem.dom_type).append(controlGroup);
			
			if(this.settings.customFieldType != 'company') {
				this.showSecurityIconForAgentFields(fieldContainer);
			}
			this.hideDeleteIconForDefaultFields(fieldContainer);
			this.hideEditIconForFields(fieldContainer);

			return fieldContainer;
		},
		getFreshField: function(type, field_type){
			var freshField             = this.fieldTemplate.toObject();
					freshField.field_type  = field_type;
					freshField.dom_type    = type;
			if (field_type == 'custom_dropdown'){
				freshField.choices = [[this.settings.customMessages.firstChoice, 0], [this.settings.customMessages.secondChoice, 0]];
			}		 
			return freshField;
		},

		addChoiceinDialog: function(data, dom){
			dom	= dom  || this.dialogDOMMap.choices;
			data	= data || [ '', Math.random()*100 ];
			var inputData = $("<input type='text' />")
													.val(unescapeHtml(data[0]))
													.attr("data_id", data[1])
													.attr('name', 'choice_'+data[1])
													.addClass('field_maxlength');
			var dropSpan  = $("<span class='dropchoice' />").append(inputData);

			var fieldSet = $("<fieldset />")
					.append("<span class='sort_handle' />")
					.append("<span class='ficon-minus delete-choice' />")
					.append(dropSpan)            
					.appendTo(dom);  

			$(this.settings.addChoice).appendTo(fieldSet); 
			var no_choices = dom.find('fieldset:visible').length;
			if(no_choices >= this.settings.maxNoOfChoices) {
				$(this.settings.addChoice).hide();
				$('<div>').addClass('max-item-error error')
							.text(translate.get('maxItemsReached'))
							.appendTo(fieldSet);
			}
			inputData.focus();
		},

		getAllChoices: function(dom){      
			 var choices = $A();         
			 dom.find('fieldset').each(function(choiceset){
					var temp = [ '', 0 ],
							input_box = $(this).find("span.dropchoice input");
							
							temp[0] = escapeHtml(input_box.val());
							temp[1] = input_box.attr("data_id");
							
					if($.trim(temp[0]) !== '') choices.push(temp);
			 });
			 return choices;
		},

		saveAllChoices: function(){
			this.settings.currentData = $H($(this.settings.currentField).data("raw"));
			this.settings.currentData.set("choices", this.getAllChoices(this.dialogDOMMap.choices));
			this.setAction(this.settings.currentData, "update");
			this.constructFieldDom(this.settings.currentData.toObject(), $(this.settings.currentField));
		},

		deleteDropDownChoice: function($this){
			if($this.parent().siblings().size() !== 0) {
				if($this.parent().find(this.settings.addChoice).length > 0) {
					$(this.settings.addChoice).appendTo($this.parent().prev());
				}
				$this.parent().remove();
			}
			var no_choices = (this.dialogDOMMap.choices).find('fieldset:visible').length;
			if(no_choices < this.settings.maxNoOfChoices) {
				$(this.settings.addChoice).show();
				$(this.dialogDOMMap.choices).find('.max-item-error').remove();
			}
		},

		deleteField: function(sourcefield){
			this.settings.currentData = $H($(sourcefield).data("raw"));
			if(/^default/.test(this.settings.currentData.get('field_type'))) {
				return;
			}
			if (confirm(this.settings.customMessages.confirmDelete)) {
				$(sourcefield).data('clone').remove();
				this.setAction(this.settings.currentData, "delete");
				$(sourcefield).data("raw", this.settings.currentData);
				if( !($(this.settings.currentField).data("fresh") || this.settings.currentData.id === '' || this.settings.currentData.id === null) ){
					$(sourcefield).hide();
				} else {
					$(sourcefield).remove();
				}
				this.hideDialog();
			}
		},

		showFieldDialog: function(element){
			this.settings.currentData = $(element).data("raw");
			var fieldtype = this.settings.currentData['field_type'];//$H(listItem.data("raw")).get('field_type');

			if ($.inArray(fieldtype, this.settings.nonEditableFields) == -1) {
				$(this.settings.dialogContainer).html(JST['formfield_props'](this.settings.currentData));
				this.dialogOnLoad(element);
				$(this.settings.customPropsModal).modal('show');
			}
		},

		closeDialog: function(e) {
			if($(this.settings.currentField).data("fresh")) {
				if($(this.settings.currentField).data('clone')) {
					$(this.settings.currentField).data('clone').remove();
				}
				$(this.settings.currentField).remove(); 
			}
			$(this.settings.currentField).removeClass('active');
		},

		hideDialog: function(){ 
			$(this.settings.customPropsModal).modal('hide');
		},

		hideDeleteIconForDefaultFields: function(listItem) {
			var fieldtype = $H(listItem.data("raw")).get('field_type');
			var deleteIcon = listItem.find('.delete-field');
			deleteIcon.removeClass('ficon-trash-strike-thru').addClass('ficon-trash-o');

			if (/^default/.test(fieldtype)) {
				deleteIcon.removeClass('ficon-trash-o').addClass('ficon-trash-strike-thru');  
			}
		},

		hideEditIconForFields: function(listItem) {
			var fieldtype = $H(listItem.data("raw")).get('field_type');
			var editIcon = listItem.find('.edit-field');
			editIcon.removeClass('ficon-edit-strike-thru').addClass('ficon-edit');

			if ($.inArray(fieldtype, this.settings.nonEditableFields) >= 0) {
				editIcon.removeClass('ficon-edit').addClass('ficon-edit-strike-thru');  
			}
		},

		showSecurityIconForAgentFields: function(listItem) {
			var isVisible = $H(listItem.data("raw")).get('visible_in_portal');
			if(!isVisible) {
				listItem.find(this.settings.privateSymbol).show();
			}
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
			
		saveCustomFields: function(ev) {
			ev.preventDefault();
			var jsonData = this.getCustomFieldJson();
			$(this.settings.fieldValues).val(jsonData.toJSON());
			this.value = $(this).data("commit")
			$(this.settings.saveBtn).prop("disabled", true);
			$(this.settings.submitForm).trigger("submit");
		},

		getCustomFieldJson: function(){
			var allfields = $A(),
				self = this;
			$(this.settings.formContainer+" li").each(function(index, domLi){
				var data = $(domLi).data("raw");
				if(data.column_name == 'default' && data.choices.length > 0) {
					delete data.choices;
				}
				delete data.dom_type;
				delete data.validate_using_regex;
				delete data.disabled_customer_data;
				if(self.settings.customFieldType == 'company') {
					delete data.required_in_portal;
					delete data.visible_in_portal;
					delete data.editable_in_signup;
					delete data.editable_in_portal;
				}
				allfields.push(data);
			});
			return allfields;
		},

		setCurrentData: function(addInDom) {
			if(this.settings.currentField !== null){            
				this.settings.currentData = $H($(this.settings.currentField).data("raw"));
				var field_type = this.dialogDOMMap['field_type'].val();
				if($(this).is('input') && $(this).attr('type')!='submit') {
					var inputFieldName = this.name;
					var currentInput = jQuery.grep(Object.keys(this.settings.fieldMap), function(item, index){
							return this.settings.fieldMap[item][0]==inputFieldName;
					});
					if(currentInput.length>0) {
						currentInput = currentInput[0];
						if(currentInput == 'field_options') {
							this.settings.currentData.set(currentInput,{'regex': this.dialogDOMMap[currentInput].prop(this.settings.fieldMap[currentInput][1])});
						}
						else
							this.settings.currentData.set(currentInput, this.dialogDOMMap[currentInput].prop(this.settings.fieldMap[currentInput][1]));
						if(currentInput == 'custom-label') {
							field_label = $.trim(this.value);
							if(field_label === '') field_label = this.settings.customMessages.untitled;
							this.settings.currentData.set("label_in_portal", field_label);
							this.value = field_label;
						}
					}
				}
				else {
					var self = this;
					$.each(this.settings.fieldMap, function(key, value) {
						if(key == 'choices') {
							if(self.settings.currentData.get('column_name') != 'default') {
								self.settings.currentData.set(key, self.getAllChoices(self.dialogDOMMap[key]));
							}
						}
						else if(key=='field_options' && field_type == 'custom_text') {
							var regexValue = self.dialogDOMMap['validate_using_regex'].prop('checked')
													? {'regex' : self.dialogDOMMap[key].prop(value[1])} 
													: null;
							self.settings.currentData.set(key, regexValue);
						}
						else if(key != 'field_type') 
							self.settings.currentData.set(key, self.dialogDOMMap[key].prop(value[1]));

					});
				}
				this.setAction(this.settings.currentData, "update");
				if(addInDom === true) {
					this.constructFieldDom(this.settings.currentData.toObject(), $(this.settings.currentField));
					$(this.settings.formContainer).sortable('refresh');
					$(this.settings.currentField).data("fresh", false);
				}
			}
		},

		dialogOnLoad: function(sourceField){ 
			try {
				$(this.settings.currentField).removeClass('active');
				this.settings.currentField = sourceField;
				$(sourceField).addClass("active");
				this.initializeDialogDomMap();
				this.initializeChoicesSort();
				$(this.settings.customPropertiesDiv).validate(this.settings.validateOptions);
			}catch(e){}
		},

		innerLevelExpand: function(checkbox){ 
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

		toggleRegexValidation: function(checkbox) {
			if(checkbox.checked) {
				$(checkbox).parents('fieldset').next().show();
			} else {
				$(checkbox).parents('fieldset').next().hide();
			}
		},

		customFieldSort: function(item, isClicked) {
			if(item.data("fresh")){
				field_label = item.text();
				type = item.data('type');
				field_type = item.data('fieldType');
				var fieldContainer;
				if(type) {
					var item_clone = item;
					if(isClicked) {
						item_clone = item.clone();
						$(this.settings.formContainer).prepend(item_clone);
						$('body').animate({
							scrollTop:0
						}, '500')
					}
					fieldContainer = this.constructFieldDom(this.getFreshField(type, field_type), item_clone);
					fieldContainer.trigger('click');
					$(this.settings.formContainer).sortable('refresh');

					item_clone = this.cloneField(fieldContainer);
					$(this.settings.clonedFormContainer).children().eq(fieldContainer.index()).before(item_clone);
					this.movePositions();
				}
			}
			$(this.settings.formContainer).find(".custom-field.exclude-me").each(function() {
				var item = $(this);
				var clone = item.data("clone");
				var position = item.position();

				clone.css("left", position.left);
				clone.css("top", position.top);
				clone.show();

				item.removeClass("exclude-me");
			});
			this.rearrangePositions();
			$(this.settings.formContainer).find('.custom-field').css("visibility", "visible");
			$(this.settings.clonedFormContainer).find('.custom-field').removeClass('in-movement')
		},

		movePositions: function() {
			$(this.settings.formContainer).find(".custom-field:not(.exclude-me)").each(function() {
				var item = $(this);
				var clone = item.data("clone");
				clone.stop(true, false);
				var position = item.position();
				clone.animate({
					left: position.left,
					top: position.top
				}, 200);
			});
		},

		rearrangePositions: function() {
			$(this.settings.formContainer).find('.custom-field').each(function() {
				var item = $(this);
				var clone = item.data("clone");

				clone.attr("data-pos", item.index());
			});
		},
		cloneField: function(item) {
			var item_clone = item.clone();
			item.data("clone", item_clone);
			var position = item.position();
			item_clone.attr('style','');
			item_clone
				.css({
					left: position.left,
					top: position.top,
					width: item.width()
				});
			return item_clone;
		},

		cloneAllFields: function() {
			var self = this;
			$(this.settings.clonedFormContainer).empty();
			$(this.settings.formContainer).find(".custom-field").each(function(i) {
				var item_clone = self.cloneField($(this));
				item_clone.attr("data-pos", i+1);
				if(item_clone.find('.select2-container').length > 0)
					item_clone.find('select').removeClass('select2');
				$(self.settings.clonedFormContainer).append(item_clone);
			});
		},

		initializeDragDropSortElements: function() {

			var self = this;
			// List of custom fields dialog
			$(this.settings.customFieldsWrapper).find('.field')
				.draggable({
					connectToSortable: this.settings.formContainer,
					helper: function() {
						var clone = $(this).clone();
						clone.find('.dom-icon').removeAttr('title').removeAttr('data-original-title').removeClass('tooltip');
						return clone;
					},
					stack:  this.settings.customFieldsWrapper + " li",
					revert: "invalid",
					appendTo: 'body'
			});
			// Custom Fields Form
			$(this.settings.formContainer)
				.sortable({
					revert: true,
					forceHelperSize: true,
					start: function(e, ui) {
						self.setCurrentData(true);
						ui.helper.addClass("exclude-me");
						$('.custom-field.ui-sortable-placeholder').addClass('exclude-me');
						$(self.settings.formContainer).find('.custom-field:not(.exclude-me)').css("visibility", "hidden");
						if(ui.helper.data('clone')) ui.helper.data("clone").hide();
						$(self.settings.clonedFormContainer).find(".custom-field").addClass('in-movement');
					},
					stop: function(ev, ui) {    
						self.customFieldSort(ui.item);
					},
					change: function(e, ui) {
						self.movePositions();
					}
				})
				.droppable();
		},

		initializeChoicesSort: function() {
			// Choices in dropdown properites box
			var self = this;
			$(this.settings.dropdownChoiceDiv)
				.sortable({
					items: 'fieldset',
					handle: ".sort_handle",
					stop: function(ev){
						self.saveAllChoices();
					}
			});
		},

		initializeDialogDomMap: function() {
			var self = this;
			$.each(this.settings.fieldMap, function(key, value) {
				if(key == 'choices') 
					self.dialogDOMMap[key] = $(self.settings.dialogContainer+" div[name='"+ value[0] + "']");
				else
					self.dialogDOMMap[key] = $(self.settings.dialogContainer + " input[name='" + value[0] + "']");
			});
		},

		init: function() {
			var self = this;
			// Populating the fields
			this.feedJsonForm(this.settings.existingFields);

			// CLONING THE CUSTOM FIELDS FOR ANIMATION EFFECT
			this.cloneAllFields();

			this.initializeDragDropSortElements();															
			this.initializeDialogDomMap();

			$(this.settings.formContainer).on('click', '.custom-field', function(e) {
				if(!$(this).hasClass('ui-sortable-helper')) { // to ignore if its being dragged
					self.showFieldDialog($(this));
				}
			});

			$(this.settings.formContainer).on('hover', 'li', function() {
				self.hideDeleteIconForDefaultFields($(this));
				self.hideEditIconForFields($(this));
			});
			$(this.settings.formContainer).on('click', '.delete-field', function(e) {
				e.stopPropagation();
				self.deleteField($(this).parents('.custom-field'));
			});

			$(document).on('click.custom-fields', '.delete-field', function(e) {
				self.deleteField(self.settings.currentField);
			});

			$(document).on('click.custom-fields', this.settings.cancelBtn, function(e) {
				self.hideDialog();
			});

			$(document).live("change.custom-fields", this.settings.nestedConfig + " input:checkbox", function(e){
				self.innerLevelExpand(e.target);
			});

			$(document).on("change.custom-fields", this.dialogDOMMap['validate_using_regex'].selector, function(e){
				self.toggleRegexValidation(e.target);
			});

			$(document).on("keyup.custom-fields", this.dialogDOMMap['label'].selector, function(e){
				$(self.settings.fieldLabel).text($(this).val());
			});

			if($.browser.msie) {
				$(this.settings.formContainer).hover(function(){
						$(this).addClass("hover");
				}, function(){
						$(this).removeClass("hover");
				});
			}

			$(document).on('click.custom-fields', this.settings.deleteChoice, function(e) {
				self.deleteDropDownChoice($(this));
			});
			$(document).on('click.custom-fields', this.settings.addChoice, function(e) { e.preventDefault(); self.addChoiceinDialog() }); 
			$(document).on('hidden.custom-fields', '.modal', function(){
				if($(this).attr('id') == self.settings.customPropsModal.slice(1)) {
					self.closeDialog();
				}
			});

			$(document).on('change.custom-fields', "input", function(e) {
				self.setCurrentData();
			});
			$(document).on('click.custom-fields', this.settings.propsSubmitBtn, function(){
				$(self.settings.customPropertiesDiv).trigger('submit');
			});

			$(document).on('click.custom-fields', this.settings.customFieldItem, function() {
				self.customFieldSort($(this), true);
			});

			$(document).on('keypress.custom-fields', this.settings.customPropertiesDiv + " input", function(e) {
				e.stopPropagation();
				var keyCode = e.which || e.keyCode || e.charCode;
				if(keyCode == 13) {
					$(self.settings.customPropertiesDiv).submit();
				}
			});

			$(this.settings.customPropertiesDiv)
					.live('submit',function(){ return false; });

			this.settings.validateOptions = {
							submitHandler: function(){
								self.setCurrentData(true);
								$(this.settings.currentField).removeClass('active');
								self.cloneAllFields();
								self.hideDialog();
							},
							rules: {
								choicelist: {
									"required":{
										depends: function(element) {
											if($(self.settings.dropdownChoiceDiv).css("display") == "block"){
													choiceValues = "";
													$.each($(self.settings.dropdownChoiceDiv).find("input"), function(index, item){
														choiceValues += item.value;
													});
													return ($.trim(choiceValues) == "");
											}else{
												 return false;
											}
									 	}
									}
								},
								"custom-label": {
									"required": true
								},
								"custom-label-in-portal": {
									"required": {
										depends: function(element) {
											return self.dialogDOMMap['visible_in_portal'].prop('checked');
										}
									}
								},
								"custom-reg-exp": {
									"required": {
										depends: function(element) {
											return self.dialogDOMMap['validate_using_regex'].prop('checked');
										}
									},
									"validate_regexp": {
										depends: function(element) {
											return self.dialogDOMMap['validate_using_regex'].prop('checked');
										}
									}
								} 
							},

							messages: {
								 choicelist: this.settings.customMessages.noChoiceMessage
							},
							onkeyup: false,
							onclick: false
					 };

			$(this.settings.saveBtn).on('click', function(e) {
				self.saveCustomFields(e);
			});

		},
		destroy: function() {
			$(document).off('click.custom-fields');
			$(document).off('change.custom-fields');
		}
	};
})(window.jQuery);
