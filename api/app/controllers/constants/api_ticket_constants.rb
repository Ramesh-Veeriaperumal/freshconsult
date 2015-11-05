module ApiTicketConstants
  # ControllerConstants
  ARRAY_FIELDS = %w(tags cc_emails attachments).freeze
  HASH_FIELDS = ['custom_fields'].freeze
  COMPLEX_FIELDS = ARRAY_FIELDS | HASH_FIELDS
  CREATE_FIELDS = %w(cc_emails, description description_html due_by email_config_id fr_due_by group_id priority
              email phone twitter_id facebook_id requester_id name responder_id source status subject type product_id
              tags attachments).freeze | ARRAY_FIELDS.map { |x| Hash[x, [nil]] } | HASH_FIELDS
  UPDATE_FIELDS = %w(description description_html due_by email_config_id fr_due_by group_id priority
              email phone twitter_id facebook_id requester_id name responder_id source status subject type product_id
              tags attachments).freeze | (ARRAY_FIELDS - ["cc_emails"]).map { |x| Hash[x, [nil]] } | HASH_FIELDS
  SHOW_FIELDS = ['include']
  ALLOWED_INCLUDE_PARAMS = ['notes', nil]
  ORDER_TYPE = TicketsFilter::SORT_ORDER_FIELDS.map(&:first).map(&:to_s).freeze
  ORDER_BY = TicketsFilter::SORT_FIELDS.map(&:first).map(&:to_s) - ['priority']
  DEFAULT_ORDER_BY = TicketsFilter::DEFAULT_SORT
  DEFAULT_ORDER_TYPE = TicketsFilter::DEFAULT_SORT_ORDER
  DELEGATOR_ATTRIBUTES = [:group_id, :responder_id, :product_id, :email_config_id, :custom_field, :requester_id, :status].freeze
  PRIORITIES = TicketConstants::PRIORITY_TOKEN_BY_KEY.keys.freeze
  SOURCES = TicketConstants::SOURCE_KEYS_BY_TOKEN.slice(:email, :portal, :phone, :chat, :mobihelp, :feedback_widget).values.freeze

  SCOPE_BASED_ON_ACTION = {
    'update'  => { deleted: false, spam: false },
    'restore' => { deleted: true, spam: false },
    'destroy' => { deleted: false, spam: false }
  }.freeze

  # all_tickets is not included because it is the default filter applied.
  # monitored_by is renamed as 'watching'
  FILTER = %w( new_and_my_open watching spam deleted ).freeze

  FIELD_TYPES = Helpdesk::TicketField::FIELD_CLASS.keys.map(&:to_s).freeze
  INDEX_FIELDS = %w(filter company_id requester_id email order_by order_type updated_since).freeze

  ATTRIBUTES_TO_BE_STRIPPED = %w(email phone name subject type tags cc_emails twitter_id custom_fields).freeze


  CLOSED = Helpdesk::Ticketfields::TicketStatus::CLOSED
  RESOLVED = Helpdesk::Ticketfields::TicketStatus::RESOLVED

  # Routes that doesn't accept any params
  NO_PARAM_ROUTES = %w(restore).freeze

  # Wrap parameters args
  WRAP_PARAMS = [:ticket, exclude: [], format: [:json, :multipart_form]].freeze

  ALLOWED_CONTENT_TYPE_FOR_ACTION = {
    create: [:json, :multipart_form],
    update: [:json, :multipart_form]
  }.freeze

  FIELD_MAPPINGS = { group: :group_id, agent: :responder_id, responder: :responder_id, requester: :requester_id, email_config: :email_config_id,
                     product: :product_id, ticket_type: :type }.freeze
end.freeze
