module Widget::TicketConstants
  include TicketConstants
  # TODO decide params and headers to store and validate
  META_INFORMATION = %w().freeze
  CREATE_FIELDS = (ApiTicketConstants::CREATE_FIELDS + %w[g-recaptcha-response]).freeze
end.freeze
