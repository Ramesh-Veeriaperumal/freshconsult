/**
 * @author venom
 * A Helper function to construct on Demand Dom elements using jQuery and associated Plugins 
 */
window.fdUtil	 = {
	// For reseting any undefined variable that comes in through a function
	make_defined: function(){
		$A(arguments).each(function (variable){
			variable = variable || "";
		});	
	}
};

window.FactoryUI = {
	link: function(_name, _href, _className){
		return jQuery("<a />")
				.attr('href', _href)
				.addClass(_className)
				.text(_name);
	},
	label:function(_name, _className){
		return jQuery("<label />")
				.addClass(_className)
				.text(_name);
	},
	text:function(_placeholder, _name, _value, _className){
		var className	= _className || "text",
			placeholder = _placeholder || "",
			name		= _name || "",
			value		= _value || "";

		return jQuery("<input type='text' />")
				.prop({ "name": name, "placeholder":placeholder })
				.addClass(className)
				.val(value);
	},
	date: function(_placeholder, _name, _value, _className, _date_format) {
		var className	= _className || "datepicker_popover",
			placeholder = _placeholder || "",
			name		= _name || "",
			value		= _value || "",
			date_format = _date_format || "mm-dd-YY";

		return jQuery("<div class='date-wrapper input-date-field'/>")
				.append(jQuery("<input type='text' />")
					.prop({ "name": name, "placeholder":placeholder, "readonly": true })
					.addClass(className)
					.val(value)
					.data('showImage',"true")
					.data('dateFormat', date_format));
	},
	password:function(_placeholder, _name, _value, _className){
		var className	= _className || "text password",
			placeholder = _placeholder || "",
			name		= _name || "",
			value		= _value || "";

		return jQuery("<input type='password' />")
				.prop({ "name": name, "placeholder":placeholder })
				.addClass(className)
				.val(value);
	},
	hidden:function(_name, _value){
		var name  = _name || "",
			value = _value || "";
		
		return jQuery("<input type='hidden' />")
					.prop({ "name" : name, "value" : value });

	},
	// Template json for choices 
	// ['choice1', 'choice2'...]
	dropdown: function(choices, _name, _className, _dataAttr){
		if(!choices) return;
		var className   = _className	|| "dropdown",
			name		= _name			|| "",
			select		= jQuery("<select />")
							.prop({ "name": name })
							.addClass(className);
		
		if (_dataAttr)
			select.data( _dataAttr);

		choices.each(function(item){
			jQuery( "<option />" )
				.text( item.value )
				.appendTo(select)
				.get(0).value = item.name;  
		});
		return jQuery(select);
	},
	optgroup: function(choices, _name, _className, _dataAttr){
		if(!choices) return;
		var className   = _className	|| "dropdown",
			name		= _name			|| "",
			select		= jQuery("<select />")
							.prop({ "name": name })
							.addClass(className);

		if(_dataAttr)
			select.data( _dataAttr);


		choices.each(function(item){
			if(item.length > 0 && (item[1] instanceof Array)){
				var _optgroup = jQuery("<optgroup label='"+item[0]+"' />");
				item[1].each(function(option){
					jQuery( "<option />" )
						.text( (option[1]) )
						.data( "unique_action", option[2] || false )
						.appendTo(_optgroup)
						.get(0).value = option[0];
				});
				_optgroup.appendTo(select);
			}else{
				jQuery( "<option />" )
						.text( (item[1]) )						
						.appendTo( select )
						.get(0).value = item[0];
			}
		});
		return jQuery(select);
	},
	paragraph: function(_placeholder, _name, _value, _className, _idName){
		var className   = _className || "paragraph",
			placeholder = _placeholder || "",
			name		= _name || "",
			value		= _value || "",
			id			= _idName || "";
			
		return jQuery("<textarea />")
					.prop({ "name": name, "id": id })
					.addClass(className)
					.val(value);
	},
	checkbox: function(_label_text, _name, _checked, _labelClass, _value, _checkboxClass, _divClass){
		var labelClass	= _labelClass || "checkbox",
			label_text		= _label_text || "",
			name		= _name  || "",
			checked		= (_checked == "true")?"checked": "" || ""
			checkboxClass = _checkboxClass || ""
			divClass = _divClass|| "";
					
		labelBox  = jQuery("<label />")
					.addClass( labelClass+divClass );
		checkBox  = jQuery("<input type='checkbox' />")
					.prop({ "name" : name, "checked": checked, value: _value || true })
					.addClass(checkboxClass);

		return labelBox.append(checkBox).append(label_text);
	},
	radiobutton: function(_choices, _label, _name, _checked, _className){
		var className = _className || 'radiolabel',
			choices = _choices,
			label		= _label || "",
			name		= _name  || "",
			checked 	= _checked || _choices[0]['name'],
			radioButtonSet = jQuery("<div />"),
			index = 0;

		choices.each(function(item){
			choice = jQuery("<input type='radio' />")
								.prop({ "name" : name, "value": item['name'], 
									"id" : item['name']+item['value']+index });
			if( checked == item['name'])
				{	choice.prop({ 'checked' : true }) }
			label = jQuery("<label  />")
								.prop({ "for" : item['name']+item['value']+index++, "class" : className })
									.text(item['value']);
			radioButtonSet.append(choice).append(label);
		})
		return radioButtonSet;
	}
};
