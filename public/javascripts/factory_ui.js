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
	text:function(_placeholder, _name, _value, _className){
		var className	= _className || "text",
			placeholder = _placeholder || "",
			name		= _name || "",
			value		= _value || "";

		return jQuery("<input type='text' />")
				.prop({ "name": name })
				.addClass(className)
				.val(value);
	},
	// Template json for choices 
	// ['choice1', 'choice2'...]
	dropdown: function(choices, _name, _className){
		if(!choices) return;
		var className   = _className	|| "dropdown",
			name		= _name			|| "",
			select		= jQuery("<select />")
							.prop({ "name": name })
							.addClass(className);
		
		choices.each(function(item){
			jQuery( "<option />" )
				.text( item.value )				
				.appendTo(select)
				.get(0).value = item.name;  
		});
		return jQuery(select);
	},
	paragraph: function(_placeholder, _name, _value, _className){
		var className   = _className || "paragraph",
			placeholder = _placeholder || "",
			name		= _name || "",
			value		= _value || "";
			
		return jQuery("<textarea />")
					.prop({ "name": name })
					.addClass(className)
					.val(value);
	},
	checkbox: function(_label, _name, _checked, _className){
		var className	= _className || "checkbox",
			label		= _label || "",
			name		= _name  || "",
			checked		= (_checked == "true")?"checked": "" || "";
					
		labelBox  = jQuery("<label />")
					.addClass( className );
		hiddenBox = jQuery("<input type='hidden' />")
					.prop({ "name" : name, "value" : false });
		checkBox  = jQuery("<input type='checkbox' />")
					.prop({ "name" : name, "checked": "checked", value: true });

		return labelBox.append(hiddenBox).append(checkBox).append(label);
	}
};
