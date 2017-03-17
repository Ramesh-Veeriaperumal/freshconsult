module TicketFilterConstants
  # ControllerConstants

  HIDDEN_FILTERS = %w(overdue due_today on_hold new open).freeze

  FILTER = (Helpdesk::Filters::CustomTicketFilter::DEFAULT_FILTERS.keys | %w(watching on_hold raised_by_me)).freeze

  INDEX_FIELDS = %w(filter ids company_id requester_id email order_by order_type updated_since include query_hash).freeze

end.freeze
