jQuery(document).ready(function() {
	jQuery("#account_timezone_offset").val(getLocalTimeZoneOffset());
	jQuery(".btn-primary").removeClass("disabled");
	jQuery(".btn-primary").attr("Submit","Loading...");
	jQuery(".btn-primary").removeAttr("disabled");

	// script to store visitor traffic info in cookie
	if(session){
		if(!(jQuery.cookie("fd_fr"))){jQuery.cookie("fd_fr",session["current_session"]["referrer"],{expires:365});}
		if(!(jQuery.cookie("fd_flu"))){jQuery.cookie("fd_flu",session["current_session"]["url"],{expires:365});}

		if(!(jQuery.cookie("fd_se"))){jQuery.cookie("fd_se",session["current_session"]["search"]["engine"],{expires:365});}

		if(!(jQuery.cookie("fd_sq"))){jQuery.cookie("fd_sq",session["current_session"]["search"]["query"],{expires:365});}

		var visits = (jQuery.cookie("fd_vi"))||0;
		jQuery.cookie("fd_vi", (parseInt(visits)+1),{expires:365});
	}

	jQuery("#google_sign_up_form").submit(function(){
		jQuery("#session_json").val(JSON.stringify(session));
		jQuery("#first_referrer").val((jQuery.cookie("fd_fr")||""));
		jQuery("#first_landing_url").val((jQuery.cookie("fd_flu")||""));
		jQuery("#first_search_engine").val((jQuery.cookie("fd_se")||""));
		jQuery("#first_search_query").val((jQuery.cookie("fd_sq")||""));
		jQuery("#pre_visits").val((jQuery.cookie("fd_vi")||0));
		jQuery('#account_domain').val(jQuery('#account_domain').val().toLowerCase().replace(/\W/g, ''));
		if (isFormValid()) {
			jQuery(".btn-primary").addClass("disabled");
			jQuery(".btn-primary").attr("value","Loading...");
			jQuery(".btn-primary").attr("disabled", "disabled");
		}
	})

	jQuery("#account_name").change(function() {
		if (jQuery("#account_domain").val() === ''){
			jQuery("#account_domain").val(jQuery(this).val().toLowerCase().replace(/\W/g, ''));
			jQuery('#account_domain').trigger('change');
		}
	})

	jQuery('#account_domain').change(function() {
		jQuery(this).val(jQuery(this).val().toLowerCase().replace(/\W/g, ''));
	})
});

function getLocalTimeZoneOffset() {
	var timeZoneOffset = (new Date()).getTimezoneOffset() / 60 * (-1);
	timeZoneOffset -= (isDST() ? 1 : 0);
	return timeZoneOffset;
}

function isFormValid() {
	var form_elements = ['user_name', 'user_email', 'account_name', 'account_domain'];
	var result = true;
	form_elements.each(function(element_id) {
		var element = jQuery('#' + element_id);
		if (element.length && !element.val()) {
			result = false;
		}
	});
	return result;
}

function isDST() {
	var today = new Date();
	var jan = new Date(today.getFullYear(), 0, 1, 0, 0, 0, 0);
	var jul = new Date(today.getFullYear(), 6, 1, 0, 0, 0, 0);
	var temp = jan.toGMTString();
	var jan_local = new Date(temp.substring(0, temp.lastIndexOf(" ")-1));
	var temp = jul.toGMTString();
	var jul_local = new Date(temp.substring(0, temp.lastIndexOf(" ")-1));
	var hoursDiffStdTime = (jan - jan_local) / (1000 * 60 * 60);
	var hoursDiffDaylightTime = (jul - jul_local) / (1000 * 60 * 60);

	return hoursDiffDaylightTime != hoursDiffStdTime;
}
