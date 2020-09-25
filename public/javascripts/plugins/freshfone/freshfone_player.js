var freshfonePlayerSettings = function () {
	var format,time;
	if((typeof soundManager != "undefined") && 
		(typeof threeSixtyPlayer != "undefined")) {
			soundManager.onready(threeSixtyPlayer.init);
	}
	jQuery(".call_duration").each(function () {
		if (jQuery(this).data("time") === undefined) { return; }
		if(jQuery(this).hasClass('freshcaller')){ return; }
		time = jQuery(this).data("time");
			if (time >= 3600) {
			 format = "hh:mm:ss";
			} else {
				format = "mm:ss";
			}
		jQuery(this).html(time.toTime(format));
	});
};
jQuery(document).ready(function(){
	freshfonePlayerSettings();
});