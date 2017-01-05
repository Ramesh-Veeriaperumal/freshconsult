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
      :date_iso_format => "%G-%m-%d",
      :short_day_with_week => "%a, %b %-d, %Y",
      :short_day_with_time => "%a, %b %-d, %Y at %l:%M %p",
    },
    :non_us => {
      :short_day => "%-d %b %Y",
      :short_day_separated => "%-d %b, %Y",
      :date_iso_format => "%G-%m-%d",
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

  MAINTENANCE_STATUS = 503

  VALID_URL_REGEX = /\A(?:(?:https?|ftp):\/\/)(?:\S+(?::\S*)?@)?(?:(?!10(?:\.\d{1,3}){3})(?!127(?:\.\d{1,3}){3})(?!169\.254(?:\.\d{1,3}){2})(?!192\.168(?:\.\d{1,3}){2})(?!172\.(?:1[6-9]|2\d|3[0-1])(?:\.\d{1,3}){2})(?:[1-9]\d?|1\d\d|2[01]\d|22[0-3])(?:\.(?:1?\d{1,2}|2[0-4]\d|25[0-5])){2}(?:\.(?:[1-9]\d?|1\d\d|2[0-4]\d|25[0-4]))|(?:(?:[a-z\u00a1-\uffff0-9]+-?)*[a-z\u00a1-\uffff0-9]+)(?:\.(?:[a-z\u00a1-\uffff0-9]+-?)*[a-z\u00a1-\uffff0-9]+)*(?:\.(?:[a-z\u00a1-\uffff]{2,})))(?::\d{2,5})?(?:\/[^\s]*)?\z/i

  # Used by API too. 
  EMAIL_VALIDATOR = /(\A[-A-Z0-9.'’_&%=~+]+@(?:[A-Z0-9\-]+\.)+(?:[A-Z]{2,15})\z)/i
  EMAIL_REGEX = /(\b[-a-zA-Z0-9.'’_&%=~+]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,15}\b)/
  EMAIL_SCANNER = /\b[-a-zA-Z0-9.'’_&%=~+]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,15}\b/
  SPECIAL_CHARACTERS_REGEX = /(?=.*([\x20-\x2F]|[\x3A-\x40]|[\x5B-\x60]|[\x7B-\x7E]))/
  AUTHLOGIC_EMAIL_REGEX = /\A[A-Z0-9_\.&%\+\-']+@(?:[A-Z0-9\-]+\.)+(?:[A-Z]{2,13})\z/i


  SPAM_EMAIL_EXACT_REGEX = /bank|paypal|finance|erection|free|apple|amazon/i
  SPAM_EMAIL_APPRX_REGEX = /b[a]+[n]+[kc]+|p[auo]+[y]+[p]+[auo]+l|finance|erection|free|a[p]+le|[a]+[m]+[a]+[z]+[aoe]+n/i

  EHAWK_SPAM_EMAIL_REGEX = /disposable|MX record bad|undeliverable|Suspect|Spam DNSBL/i
  EHAWK_SPAM_COMMUNITY_REGEX = /spam IP|repeat signup IP|repeat signup email|Scam IP|Spam Email/i
  EHAWK_IP_BLACKLISTED_REGEX = /spam blacklist|blacklist|Proxy - Anonymous|Hosting Service|Bots|Drone|Worm|Proxy - Suspect/i
  EHAWK_SPAM_GEOLOCATION_REGEX = /IP Distance Velocity 500/i
  
end
