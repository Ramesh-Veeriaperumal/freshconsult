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
	// Couldn't get the last added element in chozen.. Hence used _any_present
	if(element.val() == null)
	{
		element.val("--").trigger("liszt:updated");
		_any_present = true;
	}	
	else if (_any_present)
	{
		element.val(element.val().splice(1,1)).trigger("liszt:updated");
		_any_present = false;
	}
	else if (element.val().first() == "--" && element.val().length > 1)
	{
		if (confirm(_confirm_message))
		{			
			element.val("--").trigger("liszt:updated");
			_any_present = true;
		}
		else 
		{
			value = element.val();
			value.splice(0,1);
			element.val(value).trigger("liszt:updated");
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
	// Disable the only option
	if (selection != '--')
	{ jQuery(this).siblings('select[name="'+target+'"]').find('option[value="'+selection+'"]').prop('disabled',true); }
	return this;
}

var hideEmptySelectBoxes = function(){
	if (this.options.length == 1 && this.options[0].value == "--")
	{	jQuery(this).prev().css('display','none');
		jQuery(this).css('display','none');	}
	else
	{	jQuery(this).prev().css('display','block');
		jQuery(this).css('display','block');	}
	return this;
}

var performed_by_change = function(){ 
	if ( jQuery( this ).val() == "agent")
		{ 
			jQuery("#va_rule_performed_by_chzn > ul").slideDown('slow');
			jQuery("#va_rule_performed_by_chzn, #va_rule_performed_by_chzn > ul ").slideDown('fast');
	 	}
 	else
	  { 
	  	jQuery("#va_rule_performed_by_chzn, #va_rule_performed_by_chzn > ul ").slideUp('fast'); 
			jQuery("#va_rule_performed_by_chzn ").slideUp('slow'); 
			// jQuery("#va_rule_performed_by_chzn > ul").fadeOut('slow'); 
		}
};

var selectPerformedBy = function(){
	if ( jQuery( 'input[name="va_rule[performed_by]"]:checked' ).val() == null )
		jQuery( 'input[name="va_rule[performed_by]"][value = "agent"]' ).attr("checked","checked");
	performed_by_change.call(jQuery( 'input[name="va_rule[performed_by]"]:checked' ));
	ensure_performed_by.call(jQuery( '#va_rule_performed_by' ));
};

	jQuery('#EventList').find('select[name="from"]:not("div .event_nested_field > select")')
		.live("change", disableOtherSelectValue);

	jQuery('#EventList').find('select[name="to"]:not("div .event_nested_field > select")')
		.live("change", disableOtherSelectValue);

	jQuery('#EventList').find('div .event_nested_field > select')
		.live("change", hideEmptySelectBoxes);

	jQuery('input[name = "va_rule[performed_by]"]').live ( "change", performed_by_change	);
	jQuery("#va_rule_performed_by").live ( "change", ensure_performed_by );

	jQuery("#VirtualAgent").submit(function(e){
		var performed_by = jQuery('input[name=va_rule[performed_by]]:checked').val();
		if ( performed_by != "agent")
		{	
				jQuery('#va_rule_performed_by').remove(); 
		}
		else if( performed_by == "agent")
		{ 
			if ( jQuery('#va_rule_performed_by').val().first() == "--" ) 
			{	
				jQuery('#va_rule_performed_by').remove(); 
			}
			else
			{	
				jQuery('input[name="va_rule[performed_by]"]').remove(); 
			}
		}				
		return true;
	});