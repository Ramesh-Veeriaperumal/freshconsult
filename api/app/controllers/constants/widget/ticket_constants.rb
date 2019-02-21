module Widget::TicketConstants
  include TicketConstants
  # TODO decide params and headers to store and validate
  META_KEY_MAP = {
    'user_agent' => 'HTTP_USER_AGENT',
    'referrer' => 'HTTP_REFERER',
    'widget_source' => 'HTTP_X_WIDGET_ID'
  }.freeze
  META_FIELDS = [meta: META_KEY_MAP.keys].freeze
  CREATE_FIELDS = (ApiTicketConstants::CREATE_FIELDS + %w[g-recaptcha-response]).freeze | META_FIELDS
  PARAMS_TO_REMOVE = [:meta, :predictive, 'g-recaptcha-response'].freeze
end.freeze
