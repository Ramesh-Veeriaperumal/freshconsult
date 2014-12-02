function getDateFormat(format) {
	var date_format = jQuery('html').data('dateFormat');
	return DATE_FORMATS[date_format][format];
}
