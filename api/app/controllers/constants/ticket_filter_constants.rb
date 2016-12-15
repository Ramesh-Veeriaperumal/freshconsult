module TicketFilterConstants
  # ControllerConstants

  FILTER = ((Helpdesk::Filters::CustomTicketFilter::DEFAULT_FILTERS.keys - %w(monitored_by)) | %w(watching on_hold raised_by_me)).freeze

  INDEX_FIELDS = %w(filter company_id requester_id email order_by order_type updated_since include query_hash order).freeze

end.freeze
