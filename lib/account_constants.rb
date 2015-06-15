# encoding: utf-8
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
  
  # Default email settings for additional settings
  DEFAULTS_FONT_SETTINGS = { 
    :email_template => { 
      "font-size"   => '13px',
      "font-family" => 'Helvetica Neue, Helvetica, Arial, sans-serif'
    }
  } 

  DATA_DATEFORMATS = { 
    :non_us => {
      :moment_date_with_week  => 'ddd, D MMM, YYYY',
      :datepicker       => 'd M, yy',
      :datepicker_escaped   => 'd M yy',
      :datepicker_full_date => 'D, d M, yy',
      :mediumDate => 'd MMM, yyyy'
    },
      :us => {
      :moment_date_with_week  => 'ddd, MMM D, YYYY',
      :datepicker       => 'M d, yy',
      :datepicker_escaped   => 'M d yy',
      :datepicker_full_date => 'D, M d, yy',
      :mediumDate => 'MMM d, yyyy'
    }
  }

  DATEFORMATS_NAME_BY_VALUE = Hash[*DATEFORMATS.flatten] 

  EMAIL_VALIDATOR = /(\A[-A-Z0-9.'’_&%=~+]+@(?:[A-Z0-9\-]+\.)+(?:[A-Z]{2,15})\z)/i
  EMAIL_REGEX = /(\b[-a-zA-Z0-9.'’_&%=~+]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,15}\b)/
  EMAIL_SCANNER = /\b[-a-zA-Z0-9.'’_&%=~+]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,15}\b/

end