module ApiTicketConstants
  # ControllerConstants
  ARRAY_FIELDS = ['tags' => [],  'cc_emails' => [], 'attachments' => []]
  FIELDS = %w(cc_emails description description_html due_by email_config_id fr_due_by group_id priority email phone twitter_id facebook_id requester_id name responder_id source status subject type product_id tags) | ARRAY_FIELDS
  SHOW_FIELDS = ['include']
  ALLOWED_INCLUDE_PARAMS = ['notes', nil, '']
  RESTORE_FIELDS = []
  ORDER_TYPE = TicketsFilter::SORT_ORDER_FIELDS.map(&:first).map(&:to_s)
  ORDER_BY = TicketsFilter::SORT_FIELDS.map(&:first).map(&:to_s)
  DEFAULT_ORDER_BY = TicketsFilter::DEFAULT_SORT
  DEFAULT_ORDER_TYPE = TicketsFilter::DEFAULT_SORT_ORDER
  DELEGATOR_ATTRIBUTES = [:group_id, :responder_id, :product_id, :email_config_id, :custom_field, :requester_id, :status]

  SCOPE_BASED_ON_ACTION = {
    'update'  => { deleted: false, spam: false },
    'restore' => { deleted: true, spam: false },
    'destroy' => { deleted: false }
  }

  # all_tickets is not included because it is the default filter applied.
  # monitored_by is renamed as 'watching'
  FILTER = %w( new_and_my_open watching spam deleted )

  FIELD_TYPES = Helpdesk::TicketField::FIELD_CLASS.keys.map(&:to_s)
  INDEX_FIELDS = %w(filter company_id requester_id email order_by order_type updated_since)

  FIELDS_TO_BE_STRIPPED = %w(email phone name subject type tags cc_emails twitter_id custom_fields)

  CLOSED = Helpdesk::Ticketfields::TicketStatus::CLOSED
  RESOLVED = Helpdesk::Ticketfields::TicketStatus::RESOLVED
end
