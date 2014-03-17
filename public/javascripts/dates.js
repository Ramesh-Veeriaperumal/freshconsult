DATE_FORMATS = {
	'non_us'	: {
		'moment_date_with_week'					: 'ddd, D MMM, YYYY',
		'datepicker' 							: 'd M, yy',
		'datepicker_escaped'					: 'd M yy'
	},
	'us' 		: {
		'moment_date_with_week'					: 'ddd, MMM D, YYYY',
		'datepicker'  							: 'M d, yy',
		'datepicker_escaped'					: 'M d yy'
	}
}

function getDateFormat(format) {
	var date_format = jQuery('html').data('dateFormat');
	return DATE_FORMATS[date_format][format];
}
