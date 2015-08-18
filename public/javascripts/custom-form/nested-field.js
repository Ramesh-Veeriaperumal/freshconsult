(function ($) {
	window.CustomNestedField = function (element, options) {
		var defaults = {
			addStatus : '#addstatus'
		};
		this.nestedTree       = new NestedField("");
		this.statusChoice     = {};
		options = $.extend(options, defaults);
		CustomDropdown.call(this, element, options);
		$.extend(this.settings.fieldTemplate, {
	        levels:               []
        });
		return this;
	};

	CustomNestedField.prototype = {
        initializeNestedField: function () {
            $("#nestedTextarea").tabby(); //Tab function
            if (this.settings.currentData.field_type === "nested_field") {
                this.nestedTree.readData(this.settings.currentData.admin_choices);
                $("#nestedTextarea").val(this.nestedTree.toString());
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
			return this.settings.currentData;
		},
        setProperties: function () {
            CustomField.prototype.setProperties.call(this);
            this.getAllLevels();
            return this.settings.currentData;
        },
		getAllChoices: function (dom) {
			this.nestedTree.readData($('#nestedTextarea').val());
			return this.nestedTree.toArray();
        },
		getAllLevels: function () {
			this.settings.currentData    = $H(this.settings.currentData);
			levels = this.settings.currentData.get("levels");
			action = (this.settings.currentData.get("level_three_present")) ? ((nestedTree.third_level) ? "edit" : "delete") : "create";

			if (levels.size() < 2) levels.push({level: 3});

			if (!this.settings.currentData.get("level_three_present") && !nestedTree.third_level)
                levels.pop();

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
            $('.sections-wrapper').slideToggle("slow");
            $('#nestedEdit').slideToggle("slow");
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
		backToPreview: function () {
			this.nestedTree.readData($('#nestedTextarea').val());
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
			$(document).on('click.dialog-events', '#nested-edit-button', $.proxy(function (e) {
				e.stopPropagation();
				this.showNestedTextarea(); 
				return false;
			}, this));

			$(document).on('click.dialog-events', '#nestedDoneEdit', $.proxy(function (e) {
				e.stopPropagation();
				this.backToPreview();
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
			//Nested Field end
		}
	};
	
	CustomNestedField.prototype = $.extend({}, CustomDropdown.prototype, CustomNestedField.prototype);
})(window.jQuery);