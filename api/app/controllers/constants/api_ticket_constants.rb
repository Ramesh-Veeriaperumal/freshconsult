module ApiTicketConstants
  # ControllerConstants
  TICKET_ARRAY_FIELDS = [ 'tags' => [] ,  'cc_emails' => [], 'attachments' => [] ]
  TICKET_FIELDS = %w(cc_emails description description_html due_by email_config_id fr_due_by group_id priority email phone twitter_id facebook_id requester_id name responder_id source status subject type product_id tags) | TICKET_ARRAY_FIELDS
  ASSIGN_TICKET_FIELDS = ['user_id']
  SHOW_TICKET_FIELDS = ['include']
  ALLOWED_INCLUDE_PARAMS = ["notes", nil, ""]
  RESTORE_TICKET_FIELDS = []
  TICKET_ORDER_TYPE = TicketsFilter::SORT_ORDER_FIELDS.map(&:first).map(&:to_s)
  TICKET_ORDER_BY = TicketsFilter::SORT_FIELDS.map(&:first).map(&:to_s)

  # all_tickets is not included because it is the default filter applied.
  TICKET_FILTER = TicketsFilter::DEFAULT_VISIBLE_FILTERS.values_at(0, 2, 3, 4)

  TICKET_FIELD_TYPES = Helpdesk::TicketField::FIELD_CLASS.keys.map(&:to_s) + ["", nil]
  INDEX_TICKET_FIELDS = %w(filter company_id requester_id order_by order_type created_since updated_since)

  ORDER_BY_SCOPE = {
    'index' => true,
    'notes' => false
  }
end
