module ApiTicketConstants
  # ControllerConstants

  TICKET_ARRAY_FIELDS = [{ 'tags' => [String] }, { 'cc_emails' => [String] }, { 'attachments' => [] }]
  CREATE_TICKET_FIELDS = %w(cc_emails description description_html due_by email_config_id fr_due_by group_id priority email phone twitter_id facebook_id requester_id name responder_id source status subject type product_id tags) | TICKET_ARRAY_FIELDS
  UPDATE_TICKET_FIELDS = %w(cc_emails description description_html due_by email_config_id fr_due_by group_id priority email phone twitter_id facebook_id requester_id name responder_id source status subject type product_id tags) | TICKET_ARRAY_FIELDS
  ASSIGN_TICKET_FIELDS = ['user_id']
  RESTORE_TICKET_FIELDS = []
  TICKET_ORDER_TYPE = TicketsFilter::SORT_ORDER_FIELDS.map(&:first).map(&:to_s)
  TICKET_ORDER_BY = TicketsFilter::SORT_FIELDS.map(&:first).map(&:to_s)
  TICKET_FILTER = TicketsFilter::DEFAULT_VISIBLE_FILTERS.values_at(0, 2, 3, 4)
  TICKET_FIELD_TYPES = Helpdesk::TicketField::FIELD_CLASS.keys.map(&:to_s)
  INDEX_TICKET_FIELDS = %w(filter company_id requester_id order_by order_type created_since updated_since per_page page)
  ORDER_BY_SCOPE = {
    'index' => true,
    'notes' => false
  }
end
