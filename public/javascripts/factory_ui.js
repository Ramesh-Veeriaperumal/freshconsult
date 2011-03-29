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
}

window.FactoryUI = {
	text:function(placeholder, name, value, className){
		var className   = className	  || "text";
		placeholder = placeholder || "";
		name 		= name || "";
		value 		= value || "";
		return jQuery("<input type='text' name='"+name+"' class='"+className+"' placeholder='"+placeholder+"' value='"+value+"' />");	
	}, 
	// Template json for choices 
	// ['choice1', 'choice2'...]
	dropdown: function(choices, name, className){
		if(!choices) return;
		var className   = className	  || "dropdown";
		var name		= name		  || "";
		var	select 		= "<select name='"+name+"' class='"+className+"' >";		
		choices.each(function(item){ 			
			select += "<option value='"+item.name+"'>"+item.value+"</option>";			
		});		
		select += "</select>";
		return jQuery(select);
	},	
	paragraph: function(placeholder, name, value, className){
		var className   = className	  || "paragraph";
		placeholder = placeholder || "";
		name 		= name || "";
		value 		= value || "";
		return jQuery("<textarea type='text' name='"+name+"' class='"+className+"' placeholder='"+placeholder+"'>"+value+"</textarea>");
	},
	checkbox: function(label, name, checked, className){
		var className = className || "checkbox";
		label   = label || "";
		name    = name  || "";
		checked = (checked == "true")?"checked": "" || "";
		return jQuery("<label class='"+className+"'><input type='hidden' name='"+name+"' value=false /><input type='checkbox' name='"+name+"' "+checked+" value=true />"+label+"</label>") 
	}
};
