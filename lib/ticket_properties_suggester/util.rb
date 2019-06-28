module TicketPropertiesSuggester::Util

  ML_FIELDS_TO_PRODUCT_FIELDS_MAP = { group_id: 'group', priority: 'priority', ticket_type: 'ticket_type' }.freeze
  PRODUCT_FIELDS_TO_ML_FIELDS_MAP = ML_FIELDS_TO_PRODUCT_FIELDS_MAP.invert

  def trigger_ticket_properties_suggester?
    ticket_properties_suggester_enabled? && (@ticket.group.nil? || @ticket.ticket_type.nil? || 
    ( @ticket.priority == TicketConstants::PRIORITY_KEYS_BY_TOKEN[:low] && !Thread.current[:dispatcher_set_priority]))
  end

  def ticket_properties_suggester_enabled?
    Account.current.ticket_properties_suggester_enabled?
  end
end
