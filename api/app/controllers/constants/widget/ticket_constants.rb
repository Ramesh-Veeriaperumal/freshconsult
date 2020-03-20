module Widget::TicketConstants
  include TicketConstants
  META_KEY_MAP = {
    'user_agent' => 'HTTP_USER_AGENT',
    'referrer' => 'HTTP_REFERER',
    'widget_source' => 'HTTP_X_WIDGET_ID'
  }.freeze
  META_FIELDS = [meta: [:user_agent, :referrer, :widget_source, :seen_articles]].freeze
  # TICKET FIELDS MOVED OUTSIDE CREATE_FIELDS :
  # (type status priority description responder_id group_id company_id)
  # permitting these fields will be based on whether they are customer editable or not
  CREATE_FIELDS = %w[requester_id due_by email_config_id fr_due_by email phone source unique_external_id
                     name subject product_id] | %w[g-recaptcha-response] | ApiTicketConstants::ARRAY_FIELDS | ApiTicketConstants::HASH_FIELDS | META_FIELDS
  PARAMS_TO_REMOVE = [:meta, :predictive, 'g-recaptcha-response'].freeze
end.freeze
