var ObserverDom = {}

!function ($) {
	ObserverDom['ensure_performed_by'] = function(e){ 
		var element = $(this);
		if(!e && element.val())
			element.select2("val",element.val());
		else
		 if(!e || e.val.length == 0)
			element.select2("val",["--"]);
		else if( e.added && e.added.id == '--')
			if(confirm(event_lang['confirm_message']))	
				element.select2("val", ["--"]);
			else{
				e.val.splice(0,1);
				element.select2("val", e.val);
			}	
		else if(e.val[0] == '--')
			element.select2("val", e.val[1]);
	};

	ObserverDom['performed_by_change'] = function(){ 
		if($(this).val() == 1)
			$(".performer_data_members_container").slideDown();
	 	else
	  	$(".performer_data_members_container").slideUp(); 
	};

	ObserverDom['resizeSelect2'] = function(ev){	
		switch(true){
			case $(this).val()=='ticket_update':
			case $(this).val()=='time_sheet_action':
			case /ff_boolean/.test($(this).val()):
				$(this).prev().animate({width: '150px'}, 400);
			break;
			default:
				$(this).prev().animate({width: '303px'}, 400);
		}
	};

	ObserverDom['init'] = function(){
		if( $( 'input[name="performer_data[type]"]:checked' ).val() == null )
			$( 'input[name="performer_data[type]"][value = 1]' ).attr("checked","checked");
		
		setTimeout(function(ev){
			$.each($('#EventList .controls > select'), function(i, item){
				ObserverDom['resizeSelect2'].call(item)
			})
		}, 500);

		ObserverDom['performed_by_change'].call($( 'input[name="performer_data[type]"]:checked' ));
		ObserverDom['ensure_performed_by'].call($('.doer select'));
	};
	

	$('input[name = "performer_data[type]"]').live( "change", ObserverDom['performed_by_change']	);
	$('.doer select').live( "change", ObserverDom['ensure_performed_by'] );
	$('#EventList .controls > select').live("change", ObserverDom['resizeSelect2']);

	$("#ObserverForm").submit(function(e){
		var performed_by = $('input[name="performer_data[type]"]:checked').val();
		if( performed_by != '1' || $('#members').val().first() == "--" )
			$('#members').remove();
	});

}(window.jQuery);