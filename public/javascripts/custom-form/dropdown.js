(function($) {
	window.CustomDropdown = function(element, options) {
		var defaults = {
			customMessages : {
				untitled:         'Untitled',
				firstChoice :     'One',
				secondChoice :    'Two', 
				noChoiceMessage : 'No Choice',
				confirmDelete :   'Are you sure you want to delete this?'
			},
			addChoice :         '#addchoice',
			deleteChoice:       '.delete_choice_btn', 
			maxNoOfChoices:     '1000',
			dropdownChoiceDiv:  '.custom-choices',
			dropdown_rearrange: '.rearrange-icon'
		}
		options = $.extend(true, {}, defaults, options);
		CustomField.call(this, element, options);

		this.initialize();
		return this;
	}

	CustomDropdown.prototype = {
		getProperties: function() {
			if($(this.element).data('fresh')) {
				var freshField = this.settings.fieldTemplate;
					freshField.field_type  = $(this.element).data('field-type');
					freshField.dom_type    = $(this.element).data('type');
		 			freshField.admin_choices = [
							{'value' : this.settings.customMessages.firstChoice,
							 'name' : this.settings.customMessages.firstChoice
							}, 
							{'value' : this.settings.customMessages.secondChoice,
							 'name' : this.settings.customMessages.secondChoice
							}
						];
				this.settings.currentData = $.extend({}, freshField);
			}
			return this.settings.currentData;
		},
		getAllChoices: function(dom) {
			var choices = $A(),
			 		position = 0;        
			 dom.find('fieldset').each(function(choiceset){
					var temp = {'value' : ''},
						value_elem = $(this).find("span.dropchoice input[name^='choice_']"),
						cust_disp_elem = $(this).find("input[name='customer_display_name']"),
						sla_elem = $(this).find("input[name='stop_sla_timer']"),
						isDestroyed = $(this).data('destroy'),
						choice_id = $(this).data("choice-id");
							
					temp['value'] = escapeHtml(value_elem.val());
					if( choice_id != "undefined" && choice_id != 0) {
						temp['id'] = choice_id;
					}
					if( cust_disp_elem.length ) {
						temp['customer_display_name'] = escapeHtml(cust_disp_elem.val());
					}
					if( sla_elem.length ) {
						temp['stop_sla_timer'] = sla_elem.prop('checked');
					}
					temp['position'] = isDestroyed ? -1 : (++position);
					temp['_destroy'] = isDestroyed ? 1 : 0;
					temp['name'] = temp['value'];
							
					if($.trim(temp['name']) !== '') choices.push(temp);
			 });
			 return choices;
		},
		deleteChoiceItem: function($element){
			CustomField.prototype.initialize.call(this);
			var item 		= this.settings.currentData,
				choice_id 	= $element.parent().data('choice-id');

			//Checking delete disabled items	
			if(item.field_type == 'default_status' && 
				(choice_id == 2 || choice_id == 3 || choice_id == 4 || choice_id == 5)){

				return false;
			}

			if($element.parent().siblings(':visible').size() !== 0) {
				var choice_id 	= $element.parent().find('input').attr('data_id');

				if(choice_id != 0 && choice_id != "undefined") {
					$element.parent().hide();
					$element.parent().data('destroy', '1');
				} 
				else {
					$element.parent().remove();
				}
				this.toggleMaxLimitErrorMsg();
				this.toggleAddChoice();
			}
		},
		addChoiceItem: function(data, dom){
			CustomField.prototype.initialize.call(this);
			dom	= dom  || this.dialogDOMMap.admin_choices;
			data = $.extend(data, {	
										value : '', 
										name : '', 
										customer_display_name: '', 
										stop_sla_timer : false, 
										field_type: this.settings.currentData['field_type']
									}
							);

			if(!this.isMaxLimitReached()) {
				var fieldSet = $(JST['custom-form/template/custom_dropdown_choice']({item: data}));
				fieldSet.appendTo(dom);
				fieldSet.find("input[name^='choice_']").focus();
			}

			this.toggleAddChoice();
			this.toggleMaxLimitErrorMsg(fieldSet);

		},
		isMaxLimitReached: function(dom) {
			dom = dom || this.dialogDOMMap.admin_choices;
			var no_choices = dom.find('fieldset:visible').length;
			
			return (no_choices >= this.settings.maxNoOfChoices);
		},
		toggleAddChoice: function() {
			$(this.settings.addChoice).toggle(!this.isMaxLimitReached());
		},
		toggleMaxLimitErrorMsg: function(element) {
			if(this.isMaxLimitReached()) {
				element = element || $(this.dialogDOMMap.admin_choices).find('fieldset').last();
				$('<div>').addClass('max-item-error error')
					.text(translate.get('maxItemsReached'))
					.appendTo(element);
			} else {
				$(this.dialogDOMMap.admin_choices).find('.max-item-error').remove();
			}
		},
		attachEvents: function() {
			CustomField.prototype.attachEvents.call(this);
			$(document).on('click.dialog-events', this.settings.deleteChoice, $.proxy(function(e) {
				this.deleteChoiceItem($(e.currentTarget));
				return false;
			}, this));
			$(document).on('click.dialog-events', this.settings.addChoice, $.proxy(function(e) {
				e.preventDefault(); 
				this.addChoiceItem();
				return false;
			}, this)); 
			this.initializeChoicesSort();
		},
		initializeChoicesSort: function() {
			// Choices in dropdown properites box
			$(this.settings.dropdownChoiceDiv)
				.sortable({
					items: 	'fieldset',
					handle: this.settings.dropdown_rearrange,
					containment: this.settings.dropdownChoiceDiv,
					sort: function(e,el){
						var scrollParent = $('.custom-choices').parents('.modal-body');
						var currentOffset = scrollParent.scrollTop();
						var diff = el.position.top-currentOffset;
						if(diff<50){
							scrollParent.scrollTop(currentOffset-5);	
						}						
						else if(diff>350) {
							scrollParent.scrollTop(currentOffset+5);	
						}
					}
				});
		},
		getValidationRules: function() {
			var rules = CustomField.prototype.getValidationRules.call(this),
				choiceValidationRules = {
					rules: {
						choicelist: {
							"required":{
								depends: $.proxy(function(element) {
									if($(this.settings.dropdownChoiceDiv).css("display") == "block"){
										choiceValues = "";
										$.each( $(this.settings.dropdownChoiceDiv)
													.find("fieldset:visible")
													.find('input[name^=choice_]')
														,function(index, item){
															choiceValues += item.value;
														}
										);
										return ($.trim(choiceValues) == "");
									}else{
										return false;
									}
							 	}, this)
							}
						}
					},
					messages: {
						 choicelist: this.settings.customMessages.noChoiceMessage
					}
				}

			return $.extend(true, {}, rules, choiceValidationRules);
		}
	};

	CustomDropdown.prototype = $.extend({}, CustomField.prototype, CustomDropdown.prototype);
	
})(window.jQuery);