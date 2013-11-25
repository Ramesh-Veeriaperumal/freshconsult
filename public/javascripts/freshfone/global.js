function setRecentCallDuration () {
    "use strict";
	jQuery(".recent_calls_call_duration").each(function () {
		var time = jQuery(this).data("time");
		if (time === undefined || typeof time !== "number") { return; }
		jQuery(this).html(time.toTime());
	});
}

jQuery("[rel=remote-contact-hover]").livequery(function(){ 
  jQuery(this).popover({ 
    delayOut: 300,
    trigger: 'manual',
    offset: 5,
    html: true,
    reloadContent: false,
    template: '<div class="dbl_left arrow"></div><div class="hover_card inner"><div class="content"><p></p></div></div>',
    content: function(){
      var container_id = "user-info-div-"+$(this).data('contactId');
      return jQuery("#"+container_id).html() || "<div class='sloading loading-small loading-block' id='"+container_id+"' rel='remote-load' data-url='"+$(this).data('contactUrl')+"'></div>";
    }
  }); 
});    