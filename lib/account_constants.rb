module AccountConstants

	DATEFORMATS = {
		1 => :non_us,
		2 => :us
	}

	DATEFORMATS_TYPES = {
		:us => {
		  :short_day => "%b %-d %Y",
		  :short_day_separated => "%b %-d, %Y",
		  :short_day_with_week => "%a, %b %-d, %Y",
		  :short_day_with_time => "%a, %b %-d, %Y at %l:%M %p",
		},
		:non_us => {
		  :short_day => "%-d %b %Y",
		  :short_day_separated => "%-d %b, %Y",
		  :short_day_with_week => "%a, %-d %b, %Y",
		  :short_day_with_time => "%a, %-d %b, %Y at %l:%M %p",
		}
	}

	DATA_DATEFORMATS = { 
		:non_us	=> {
			:moment_date_with_week	=> 'ddd, D MMM, YYYY',
			:datepicker 			=> 'd M, yy',
			:datepicker_escaped		=> 'd M yy',
			:datepicker_full_date	=> 'D, d M, yy'
		},
	    :us => {
			:moment_date_with_week	=> 'ddd, MMM D, YYYY',
			:datepicker  			=> 'M d, yy',
			:datepicker_escaped		=> 'M d yy',
			:datepicker_full_date	=> 'D, M d, yy'
		}
	}	
	
	DATEFORMATS_NAME_BY_VALUE = Hash[*DATEFORMATS.flatten]	

end