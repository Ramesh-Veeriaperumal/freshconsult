(function ($) {
	window.CustomNestedField = function (element, options) {
		var defaults = {
			addStatus : '#addstatus'
		};
		this.revamped         = nested_field_revamp_enabled;
		this.nestedTree       = new NestedField("", this.revamped);
		this.statusChoice     = {};
		options = $.extend(options, defaults);
		CustomDropdown.call(this, element, options);
		$.extend(this.settings.fieldTemplate, {
	        levels:               []
        });
		this.parentSection = "#level1-section";
		this.sortableClass = ".nested-choices";
		return this;
	};

	CustomNestedField.prototype = {
        initializeNestedField: function () {
            $("#nestedTextarea").tabby(); //Tab function
            if (this.settings.currentData.field_type === "nested_field") {
								this.nestedTree.readData(this.settings.currentData.admin_choices);
                if(!this.revamped || $(this.element).data('fresh')) {
                	$("#nestedTextarea").val(this.nestedTree.toString());
                }else {
									this.buildNestedContent(this.settings.currentData.admin_choices, $(this.parentSection));
                }
                $("#nest-category").html(this.nestedTree.getCategory());
                this.onCategoryChange($('#nest-category'));
                this.onSubCategoryChange($('#nest-subcategory'));
            }
		},
		getProperties: function () {
			if ($(this.element).data('fresh')) {
				var freshField  = this.settings.fieldTemplate,
                    text        = "category 1 \n" +
                                    "\tsubcategory 1\n" +
                                    "\t\titem 1\n" +
                                    "\t\titem 2\n" +
                                    "\tsubcategory 2\n" +
                                    "\t\titem 1\n" +
                                    "\t\titem 2\n" +
                                    "\tsubcategory 3\n" +
                                    "category 2 \n" +
                                    "\tsubcategory 1\n" +
                                    "\t\titem 1\n" +
                                    "\t\titem 2\n";
					freshField.field_type		= $(this.element).data('field-type');
					freshField.dom_type			= $(this.element).data('type');
					// freshField.type          = 'dropdown';
					freshField.admin_choices	= text;
					freshField.label			= "";
					freshField.label_in_portal	= "";
					freshField.levels			= [
													{level: 2, label: "", label_in_portal: ""},
													{level: 3, label: "", label_in_portal: ""}
												];
					this.settings.currentData	= $.extend({}, freshField);
			}

			this.settings.currentData.isFresh = $(this.element).data('fresh');
			if(this.revamped)	{
				this.settings.currentData["levelLabels"] = [this.settings.currentData.label]
				.concat(this.settings.currentData.levels.map(function(x){x.label_in_portal}));
			}
			return this.settings.currentData;
		},
		setProperties: function () {
			CustomField.prototype.setProperties.call(this);
			this.getAllLevels();
			return this.settings.currentData;
		},
		getAllChoices: function (dom) {
			if(!this.revamped || this.settings.currentData.get("isFresh")) {
				this.nestedTree.readData($('#nestedTextarea').val());
					return this.nestedTree.converttoArray();
			}else {
				return this.getAllChoicesValues(dom.find(this.parentSection));
			}
		},
		getAllChoicesValues: function ($section, selector) {
			var choices = $A(),
			 		position = 0;
			var _this = this,
				$dependentSection = $section.next();
			selector = selector || '';
			$section.find(selector + " .fieldset").each(function(choiceset){
				var temp = {'value' : '', 'choices' : []},
					value_elem = $(this).find("span.dropchoice input[name^='choice_']"),
					isDestroyed = $(this).data('destroy'),
					choice_id = $(this).data("choice-id");
						
				temp['value'] = escapeHtml(value_elem.val());
				if( choice_id != "undefined" && choice_id != 0) {
					temp['id'] = choice_id;
				}
				temp['position'] = isDestroyed ? -1 : (++position);
				temp['destroyed'] = isDestroyed;
				temp['name'] = temp['value'];
				var nestedElementSelector = "[data-nestedparent-id=" + choice_id + "]"
				if($dependentSection.find(nestedElementSelector).length){
					temp['choices'] = _this.getAllChoicesValues($dependentSection, nestedElementSelector);
				}
				if($.trim(temp['name']) !== '') choices.push(temp);
			});
			return choices;
		},
		getAllLevels: function () {
			this.settings.currentData    = $H(this.settings.currentData);
			levels = this.settings.currentData.get("levels");
			action = (this.settings.currentData.get("level_three_present")) ? ((this.nestedTree.third_level) ? "edit" : "delete") : "create";
			if (levels.length < 2) levels.push({level: 3});
			if (!this.settings.currentData.get("level_three_present") && !this.nestedTree.third_level){
                levels.pop();
			}

			this.settings.currentData.set("levels", levels.map(function (item) {
			  return {
			    label           : escapeHtml($("#agentlevel" + item.level + "label").val()),
			    label_in_portal : escapeHtml($("#customerslevel" + item.level + "label").val()),
			    description     : '',
			    level           : item.level,
			    id              : (item.id || null),
			    position        : 1,
			    type            : 'dropdown',
			    action          : (item.level === 3) ? action : "edit"
			  }
			}));
	
			this.settings.currentData = this.settings.currentData.toObject();
		},
		showNestedTextarea: function () {
            var effect      = 'slide',
                options     = { direction: 'top' },
                duration    = 500;
            $('#nestedFieldPreview').slideToggle();
            $('#nestedEdit').slideToggle().focus();
		},
		nestedFieldValidation: function () {
			$.validator.addMethod("nestedTree", $.proxy(function (value, element, param) {
				_condition = true;
				if (this.settings.currentData['field_type'] === "nested_field") {
				  this.nestedTree.readData(value);
				  _condition = this.nestedTree.second_level;
				}
				return _condition;
			}, this), translate.get('nested_tree_validation'));

			$.validator.addMethod("uniqueNames", $.proxy(function(value, element, param) {
				_condition = true;
				levels = [1, 2, 3];
				if (this.settings.currentData['field_type'] === "nested_field") {
				  current_level = $(element).data("level");
				  levels.each(function (i) {
				    if(current_level === i || !_condition) return;
				    _condition = ($("#agentlevel"+i+"label").val().strip().toLowerCase() != $(element).val().strip().toLowerCase())
				  });
				}
			return _condition;
			}, this), translate.get("nested_unique_names"));  
		},
		getValidationRules: function () {
			var rules = CustomField.prototype.getValidationRules.call(this),
				nestedValidationRules = {
					rules: {
						"agentlabel": {
							"required":{
								depends: function(element){ return ($("#NestedFieldLabels").css("display") != "none") }
							},
							"uniqueNames": true
						},
						"customerslabel": {
							"required":{
								depends: function(element){ return ($("#NestedFieldLabels").css("display") != "none") }
							}
						},                          
						"agentlevel2label": {
							"required":{
								depends: function(element){ return ($("#NestedFieldLabels").css("display") != "none") }
							},
							"uniqueNames": true
						},
						"customerslevel2label": {
							"required":{
								depends: function(element){ return ($("#NestedFieldLabels").css("display") != "none") }
							}	
						},                          
						"agentlevel3label": {
							"required":{
								depends: $.proxy(function(element){
									return (($("#NestedFieldLabels").css("display") != "none") && this.nestedTree.third_level); 
								}, this)
							},
							"uniqueNames": true
						},
						"customerslevel3label": {
							"required":{
								depends: $.proxy(function(element){ 
									return (($("#NestedFieldLabels").css("display") != "none") && this.nestedTree.third_level); 
								}, this)
							}
						},
						"nestedTextarea": {
							"required": {
								depends: function(element){ return ($("#NestedFieldLabels").css("display") != "none") }
							},
							"nestedTree": true
						}
					},
					messages: {
						"agentlevel3label": {
							required: translate.get('nested_3rd_level')
						},
						"customerslevel3label": {
							required: translate.get('nested_3rd_level')
						}
					}
				}
			this.nestedFieldValidation();
			return $.extend(true, {}, rules, nestedValidationRules);
		},
		backToPreview: function (data) {
			this.nestedTree.readData(data);
			$("#nest-category").html(this.nestedTree.getCategoryEscaped()).trigger("change");
			setTimeout(this.showNestedTextarea, 200);
		},
		onCategoryChange: function ($this) {
			$("#nest-subcategory").html(this.nestedTree.getSubcategoryEscaped(
                                        escapeHtml($this.children('option:selected').text())
                                    )).trigger("change");
		},
		onSubCategoryChange: function ($this) {
			$("#nest-item").html(this.nestedTree.getItemsEscaped(
                                    escapeHtml($("#nest-category option:selected").text()),
                                    escapeHtml($this.children("option:selected").text())
                                ));
		},
		attachEvents: function () {
			//Nested Field start
			CustomField.prototype.attachEvents.call(this);
			this.initializeNestedField();
			$(document).on('shown.custom-fields', '.modal', $.proxy(function(e){
				$(this.parentSection).find("input[name^='choice_']:first").click();
			}, this));
			$(document).on('click.dialog-events', '#nested-edit-button', $.proxy(function (e) {
				e.stopPropagation();
				this.showNestedTextarea();
				$('.modal-body').animate({scrollTop : $("#nestedEdit").position().top},200);
				return false;
			}, this));

			$(document).on('click.dialog-events', '#nestedDoneEdit', $.proxy(function (e) {
				e.stopPropagation();
				if($('#nestedTextarea').length && $('#nestedTextarea').valid()){
					this.backToPreview($('#nestedTextarea').val());
				} else if(this.revamped){
					this.backToPreview(this.getAllChoicesValues($(this.parentSection)));
				}
				return false;
			}, this));

			$(document).on('change.dialog-events', '#nest-category', $.proxy(function (e){
				e.stopPropagation();
				this.onCategoryChange($(e.target));
				return false;
			}, this));

			$(document).on('change.dialog-events', '#nest-subcategory', $.proxy(function (e){
				e.stopPropagation();
				this.onSubCategoryChange($(e.target));
				return false;
			}, this));

			$(document).on('click.dialog-events, focus.dialog-events', '.custom-choices input[name^="choice_"]', $.proxy(function(e) {
				e.preventDefault();
				$('fieldset').removeClass('error-choice');
				$('.nested-note').removeClass('error-note');
				$(".add-choice input").removeAttr('disabled');
				this.onClickChoiceItem(e.target);
			}, this));

			$('.add-choice input').keypress($.proxy(function(e) {
				$('fieldset').removeClass('error-choice');
				e.stopPropagation();
				var keyCode = e.which || e.keyCode || e.charCode;
				if (keyCode == 13) {
					var $currentSection = e.target.closest('.nested-section'),
					parentId = jQuery($currentSection).find(".nested-choice-list:visible").data('nestedparent-id'),
					parentTarget = jQuery($currentSection.previous()).find("[name='choice_" + parentId + "']"),
					errorTarget = $(e.target).val().trim().length && parentTarget.length ? parentTarget : $(e.target);
					if(!errorTarget.val().trim().length) {
						errorTarget.closest('fieldset').removeClass('selected-field').addClass('error-choice');
						e.target.setValue('');
						$('.nested-note').addClass('error-note');
						return false;
					}
					this.addChoiceItem(e.target);
				}
			}, this));
			$(document).on('click.dialog-events', '.delete-choice', $.proxy(function(e) {
				$(e.target.next()).addClass('restore-delete');
				this.deleteChoiceItem(e.target.closest('[data-choice-id]'), true);
				return false;
			}, this));
			$(document).on('click.dialog-events', '.restore-delete', $.proxy(function(e) {
				$(e.target).removeClass('restore-delete');
				this.deleteChoiceItem(e.target.closest('[data-choice-id]'), false);
				return false;
			}, this));
			this.initializeChoicesSort();
			//Nested Field end
		},
		onClickChoiceItem: function(target){
			var dom = this.dialogDOMMap.admin_choices,
				choiceId = target.name.replace("choice_", ""),
				$currentSection = $(target).closest('.nested-section'),
				$dependentSection = jQuery($currentSection).next();
				var attr = $(target).attr("disabled");
				$currentSection.find("fieldset").removeClass('selected-field');
				if(typeof attr === typeof undefined || attr === false){
					$(target).closest("fieldset").addClass("selected-field");
				}
			if($dependentSection.length) {
				$dependentSection.find("[data-nestedparent-id]").hide();
				var dependentSecList = $dependentSection.find("[data-nestedparent-id="+ choiceId +"]");
				if(dependentSecList.length){
					dependentSecList.show();
				}else {
					this.buildNestedContent([], $dependentSection, choiceId);
				}
				var nextClickItem = dependentSecList.children().length ? dependentSecList.find("input[name^='choice_']:first")
				: $dependentSection.find(".add-choice input[name^='choice_']");
				if($(target).closest(".add-choice").length){
					$dependentSection.find(".add-choice input[name^='choice_']").attr('disabled', true);
				}
				this.onClickChoiceItem(nextClickItem[0]);
			}
		},
		addChoiceItem: function(target){
			levelId = target.dataset.levelId;
			dom	= $(this.dialogDOMMap.admin_choices.find("#level"+ levelId +"-section .nested-choice-list:visible"));
			var cItem = {
					name: target.value,
					id: target.name.replace("choice_", ""),
					value: target.value
				}
			var fieldSet = $(JST['custom-form/template/nested_dropdown_choice']({item: cItem}));
			fieldSet.appendTo(dom);
			target.setAttribute("name", "choice_" + new Date().getTime());
			target.clear().focus();
		},
		initializeChoicesSort: function() {
			// Choices in dropdown properites box
			$(this.sortableClass)
				.sortable({
					items: 	'fieldset',
					handle: this.settings.dropdown_rearrange,
					sort: function(e,el){
						var scrollParent = $('.custom-choices').parents('.modal-body .nested-choice-list');
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
		deleteChoiceItem: function(target, deleteItem){
			deleteItem ? target.addClassName('deleted-choice') : target.removeClassName('deleted-choice');
			target.setAttribute('data-destroy', deleteItem);
			var choiceId = $(target).data('choice-id'),
			$dependentSection = $(target.closest('.nested-section').next()),
			_this = this;
			if($dependentSection.length){
				$dependentSection.find(".add-choice input[name^='choice_']").attr('disabled', deleteItem);
				$dependentSection.find("[data-nestedparent-id="+ choiceId +"]")
				.children().each(function(index, value){
					_this.deleteChoiceItem(value, deleteItem);
				});

			}
		},
		buildNestedContent: function(choices, $currentSection, parentId) {
			var dataParentId = parentId ? 'data-nestedparent-id =' + parentId : '',
			htmlContent = '<div class="nested-choice-list" ' + dataParentId + ' >',
			_this = this;
			choices.each(function(choice){
				var cItem = {
					name: choice.name,
					id: choice.id,
					destroyed: choice.destroyed ? choice.destroyed : false,
					value: choice.value
				}
				htmlContent += JST['custom-form/template/nested_dropdown_choice']
					({item: _.extend(cItem)});
				var $dependentSection = $currentSection.next();
				if(choice.choices.length && $dependentSection.length){
					_this.buildNestedContent(choice.choices, $dependentSection, choice.id);
				}
			});
			htmlContent += '</div>';
			$currentSection.find(".nested-choices").append(htmlContent);
		},
		validateNestedChoices: function() {
			var level1List = $("#level1-section .fieldset[data-destroy='false']").length,
			level2List = $("#level2-section .fieldset[data-destroy='false']").length
			if(!this.settings.currentData.isFresh && !( level1List && level2List && jQuery("#CustomProperties").valid())){
				$('.nested-note').addClass('error-note');
				Object.keys($("#CustomProperties").validate().errorMap).each(function(value){
					$('[name="'+value+'"]').closest('fieldset').addClass('error-choice').removeClass('selected-field');
				});
				return true;
			}
		}
	};
	
	
	CustomNestedField.prototype = $.extend({}, CustomDropdown.prototype, CustomNestedField.prototype);
})(window.jQuery);