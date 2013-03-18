var _from, _to, _updated, _confirm_message, _any_present;
var from_to = { from : 'to', to : 'from' }

var set_observer_keywords = function(from, to, updated, confirm_message){
	_from = from;
	_to = to;
	_updated = updated;
	_confirm_message = confirm_message;
};

var ensure_performed_by = function(){ 
	
	var element = jQuery(this);	
	var value = jQuery(this).val();
	// Couldn't get the last added element in chozen.. Hence used _any_present
	if(value == null)
	{
		console.log("nullvalue")
		element.select2("val",["--"]);
		_any_present = true;
	}
	else if (_any_present)
	{
		element.select2("val", value[1]);
		_any_present = false;
	}
	else if (value.first() == "--" && value.length > 1)
	{
		if (confirm(_confirm_message))	
		{			
			element.select2("val", ["--"])
			_any_present = true;
		}
		else 
		{
			value.splice(0,1);
			console.log(value);
			element.select2("val", value);
			_any_present = false;
		}	
	}
};

var disableOtherSelectValue = function(){
	selection = jQuery(this).val();
	target = from_to[jQuery(this).prop('name')];
	// Enable all options for the nearby select
	jQuery(this).siblings('select[name="'+target+'"]').find('option').each( function(){
		jQuery(this).prop('disabled', false);
	});
	// Disable the selected option
	if (selection != '--')
	{ jQuery(this).siblings('select[name="'+target+'"]').find('option[value="'+selection+'"]').prop('disabled',true); }
	return this;
}

var performed_by_change = function(){ 
	if ( jQuery( this ).val() == 1)
		{ 
			jQuery(".va_rule_performer_members_container").slideDown();
	 	}
 	else
	  { 
	  	jQuery(".va_rule_performer_members_container").slideUp(); 
			// jQuery("#va_rule_performer_chzn > ul").fadeOut('slow'); 
		}
};

var selectPerformedBy = function(){
	if ( jQuery( 'input[name="va_rule[performer][type]"]:checked' ).val() == null )
		jQuery( 'input[name="va_rule[performer][type]"][value = 1]' ).attr("checked","checked");
	performed_by_change.call(jQuery( 'input[name="va_rule[performer][type]"]:checked' ));
	ensure_performed_by.call(jQuery('.doer select'));
};

	jQuery('#EventList select[name="from"]:not("div .event_nested_field > select")')
		.live("change", disableOtherSelectValue);

	jQuery('#EventList select[name="to"]:not("div .event_nested_field > select")')
		.live("change", disableOtherSelectValue);

	jQuery('input[name = "va_rule[performer][type]"]').live ( "change", performed_by_change	);
	jQuery('.doer select').live ( "change", ensure_performed_by );

	jQuery("#VirtualAgent").submit(function(e){
		var performed_by = jQuery('input[name="va_rule[performer][type]"]:checked').val();
		if ( performed_by != '1' || jQuery('#va_rule_performer_members').val().first() == "--" )
			jQuery('#va_rule_performer_members').remove();
	});