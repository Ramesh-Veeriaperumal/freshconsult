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
    email_template: {
      'font-size' => '14px',
      'font-family' => '-apple-system, BlinkMacSystemFont, Segoe UI, Roboto, Helvetica Neue, Arial, sans-serif'
    }
  }.freeze

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
  TIME_ZONES = ActiveSupport::TimeZone.all.map(&:name).freeze

  VALID_URL_REGEX = /\A(?:(?:https?|ftp):\/\/)(?:\S+(?::\S*)?@)?(?:(?!10(?:\.\d{1,3}){3})(?!127(?:\.\d{1,3}){3})(?!169\.254(?:\.\d{1,3}){2})(?!192\.168(?:\.\d{1,3}){2})(?!172\.(?:1[6-9]|2\d|3[0-1])(?:\.\d{1,3}){2})(?:[1-9]\d?|1\d\d|2[01]\d|22[0-3])(?:\.(?:1?\d{1,2}|2[0-4]\d|25[0-5])){2}(?:\.(?:[1-9]\d?|1\d\d|2[0-4]\d|25[0-4]))|(?:(?:[a-z\u00a1-\uffff0-9]+-?)*[a-z\u00a1-\uffff0-9]+)(?:\.(?:[a-z\u00a1-\uffff0-9]+-?)*[a-z\u00a1-\uffff0-9]+)*(?:\.(?:[a-z\u00a1-\uffff]{2,})))(?::\d{2,5})?(?:\/[^\s]*)?\z/i

  # Used by API too.  NAMED_EMAIL_VALIDATOR Validates "name"<email> | name<email> | email. This is to accomodate the old UI behaviour
  NAMED_EMAIL_VALIDATOR = /(\A[-A-Z0-9.'’_&%=~+]+@(?:[A-Z0-9\-]+\.)+(?:[A-Z]{2,15})\z)|([\w\p{L}][^<\>]*)<(\b[A-Z0-9.'_&%+-]+@[A-Z0-9.-]+\.[A-Z]{2,15}\b)\>\z|\A<!--?((\b[A-Z0-9.'_&%+-]+)@[A-Z0-9.-]+\.[A-Z]{2,15}\b)-->?\z/i
  EMAIL_VALIDATOR = /\A[-A-Z0-9.'’_&%=~+]+@(?:[A-Z0-9\-]+\.)+(?:[A-Z]{2,15})\z/i
  EMAIL_REGEX = /([-a-zA-Z0-9.'’_&%=~+]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,15})/
  EMAIL_SCANNER = /\b[-a-zA-Z0-9.'’_&%=~+]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,15}\b/
  SPECIAL_CHARACTERS_REGEX = /(?=.*([\x20-\x2F]|[\x3A-\x40]|[\x5B-\x60]|[\x7B-\x7E]))/
  AUTHLOGIC_EMAIL_REGEX = /\A[A-Z0-9_\.&%\+\-']+@(?:[A-Z0-9\-]+\.)+(?:[A-Z]{2,13})\z/i

  NEW_NAMED_EMAIL_VALIDATOR = /(\A[-A-Z0-9'’_&%=~+]+(?:\.[^<>()\[\]\\.,;:\s@"]+)*@(?:[A-Z0-9\-]+\.)+(?:[A-Z]{2,15})\z)|([\w\p{L}][^<\>]*)<(\b[A-Z0-9'_&%+-]+(?:\.[^<>()\[\]\\.,;:\s@"]+)*@[A-Z0-9.-]+\.[A-Z]{2,15}\b)\>\z|\A<!--?((\b[A-Z0-9'_&%+-]+(?:\.[^<>()\[\]\\.,;:\s@"]+)*)@[A-Z0-9.-]+\.[A-Z]{2,15}\b)-->?\z/i.freeze
  NEW_EMAIL_VALIDATOR = /\A[-A-Z0-9'’_&%=~+]+(?:\.[^<>()\[\]\\.,;:\s@"]+)*@(?:[A-Z0-9\-]+\.)+(?:[A-Z]{2,15})\z/i.freeze
  NEW_EMAIL_REGEX = /([-a-zA-Z0-9'’_&%=~+]+(?:\.[^<>()\[\]\\.,;:\s@"]+)*@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,15})/.freeze
  NEW_EMAIL_SCANNER = /\b[-a-zA-Z0-9'’_&%=~+]+(?:\.[^<>()\[\]\\.,;:\s@"]+)*@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,15}\b/.freeze
  NEW_AUTHLOGIC_EMAIL_REGEX = /\A[A-Z0-9_&%\+\-']+(?:\.[^<>()\[\]\\.,;:\s@"]+)*@(?:[A-Z0-9\-]+\.)+(?:[A-Z]{2,13})\z/i.freeze


  SPAM_EMAIL_EXACT_REGEX = /bank|paypal|finance|erection|free|apple|amazon/i
  SPAM_EMAIL_APPRX_REGEX = /b[a]+[n]+[kc]+|p[auo]+[y]+[p]+[auo]+l|finance|erection|free|a[p]+le|[a]+[m]+[a]+[z]+[aoe]+n/i

  EHAWK_SPAM_EMAIL_REGEX = /disposable|MX record bad|undeliverable|Suspect|Spam DNSBL|Temporary/i
  EHAWK_SPAM_COMMUNITY_REGEX = /spam IP|repeat signup IP|repeat signup email|Scam IP|Spam Email/i
  EHAWK_IP_BLACKLISTED_REGEX = /spam blacklist|blacklist|Proxy - Anonymous|Hosting Service|Bots|Drone|Worm|Proxy - Suspect/i
  EHAWK_SPAM_GEOLOCATION_REGEX = /IP Distance Velocity 500/i

  DEFAULT_FORUM_POST_SPAM_REGEX = "(gmail|kindle|f.?a.?c.?e.?b.?o.?o.?k|apple|microsoft|google|aol |hotmail|mozilla|q.?u.?i.?c.?k.?b.?o.?o.?k.?s?|norton|netgear|bsnl|webroot|cann?on|hp.?printer|lexmark.?printer|avg.?antivirus|symantec|avast|mcafee|bitty.?browser|netscape|belkin|dlink|tp-link|buffalo.?router|deepnet.?explorer|cisco|hitachi|linksys|panda|bitdefender|bullguard|trend.?micro|avira|kaspersky|plenty.?of.?fish|pof |zoho|rogers |windstream|sbcglobal|verizon |icloud |roadrunner |thunderbird|sasktel |hewlett.?packard|bell.?canada|skype |webroot |dell ).*(s.?u.?p.?p.?o.?r.?t| p.?h.?o.?n.?e|n.?u.?m.?b.?e.?r|t.?o.?l.?l)"

  ATTACHMENT_LIMIT = 20

  # min is used by default
  DASHBOARD_LIMITS = {
    min: { dashboard: 15, widgets: { scorecard: 15, bar_chart: 5, csat: 3, leaderboard: 3, ticket_trend_card: 2, time_trend_card: 2, sla_trend_card: 2, freshcaller_call_trend: 5, freshcaller_availability: 5, freshcaller_time_trend: 5, freshcaller_sla_trend: 5, freshchat_scorecard: 5, freshchat_bar_chart: 5, freshchat_availability: 5, freshchat_csat: 5, freshchat_time_trend: 5 }, total_widgets: 32 },
    mid: { dashboard: 20, widgets: { scorecard: 20, bar_chart: 7, csat: 3, leaderboard: 3, ticket_trend_card: 3, time_trend_card: 3, sla_trend_card: 3, freshcaller_call_trend: 5, freshcaller_availability: 5, freshcaller_time_trend: 5, freshcaller_sla_trend: 5, freshchat_scorecard: 5, freshchat_bar_chart: 5, freshchat_availability: 5, freshchat_csat: 5, freshchat_time_trend: 5 }, total_widgets: 32 },
    max: { dashboard: 25, widgets: { scorecard: 25, bar_chart: 9, csat: 3, leaderboard: 3, ticket_trend_card: 4, time_trend_card: 4, sla_trend_card: 4, freshcaller_call_trend: 5, freshcaller_availability: 5, freshcaller_time_trend: 5, freshcaller_sla_trend: 5, freshchat_scorecard: 5, freshchat_bar_chart: 5, freshchat_availability: 5, freshchat_csat: 5, freshchat_time_trend: 5 }, total_widgets: 32 }
  }.freeze

  OMNI_WIDGET_LIMITS = { widgets: { freshcaller_call_trend: 5, freshcaller_availability: 5, freshcaller_time_trend: 5, freshcaller_sla_trend: 5, freshchat_scorecard: 5, freshchat_bar_chart: 5, freshchat_availability: 5, freshchat_csat: 5, freshchat_time_trend: 5 }, total_widgets: 32 }.freeze

  PAID_BY_RESELLER = {
    'Yes' =>  true,
    'No' => false
  }.freeze

  HIPAA_ENCRYPTION_ALGORITHM = 'AES-256-CBC'
  SANDBOX_TRAIL_PERIOD = 180
  MAX_INVOICE_EMAILS = 1

  ANONYMOUS_EMAIL = 'freshdeskdemo'.freeze
  ANONYMOUS_ACCOUNT_NAME = 'Example'.freeze

  WIDGET_COUNT_FOR_PLAN = { sprout: 1, non_sprout: 10 }.freeze
  FRESHSALES_SUBSCRIPTION_URL = 'https://%{domain}/subscription'.freeze
  FRESHWORKSCRM_SUBSCRIPTION_URL = 'https://%{domain}/subscriptions'.freeze
  DEFAULT_SKILL_LIMIT = 180
  MULTI_PRODUCT_LIMIT = 5
  IGNORE_SIGNUP_PARAMS = ['company_name'].freeze

  DEFAULT_AGENT_AVAILABILITY_REFRESH_TIME = 60

  FM_TRIAL_EVENT_NAME = 'Fdesk Trial Plan'.freeze

  def attachment_limit
    @attachment_limit ||= Account.current.outgoing_attachment_limit_25_enabled? ? 25 : ATTACHMENT_LIMIT
  end

  class << self
    def named_email_validator
      return NAMED_EMAIL_VALIDATOR if Account.current.nil?

      Account.current.new_email_regex_enabled? ? NEW_NAMED_EMAIL_VALIDATOR : NAMED_EMAIL_VALIDATOR
    end

    def email_validator
      return EMAIL_VALIDATOR if Account.current.nil?

      Account.current.new_email_regex_enabled? ? NEW_EMAIL_VALIDATOR : EMAIL_VALIDATOR
    end

    def email_regex
      return EMAIL_REGEX if Account.current.nil?

      Account.current.new_email_regex_enabled? ? NEW_EMAIL_REGEX : EMAIL_REGEX
    end

    def email_scanner
      return EMAIL_SCANNER if Account.current.nil?

      Account.current.new_email_regex_enabled? ? NEW_EMAIL_SCANNER : EMAIL_SCANNER
    end

    def authlogic_email_regex
      return AUTHLOGIC_EMAIL_REGEX if Account.current.nil?

      Account.current.new_email_regex_enabled? ? NEW_AUTHLOGIC_EMAIL_REGEX : AUTHLOGIC_EMAIL_REGEX
    end
  end

end
