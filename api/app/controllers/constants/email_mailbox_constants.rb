module EmailMailboxConstants
  PARAMS_MAPPING = {
    support_email: :reply_email,
    default_reply_email: :primary_role
  }.freeze
  ACCESS_TYPE_PARAMS_MAPPING = { mail_server: :server_name }.freeze
  PARAMS_TO_DELETE = %i[mailbox_type freshdesk_mailbox custom_mailbox].freeze
  ORDER_BY = %w[group_id product_id].freeze
  ORDER_TYPE = %w[desc asc].freeze
  DEFAULT_ORDER_TYPE = 'asc'.freeze

  MAILBOX_FIELDS = %w[mail_server port use_ssl delete_from_server authentication user_name password].freeze
  INCOMING_HASH_FIELDS = [incoming: MAILBOX_FIELDS].freeze
  OUTGOING_HASH_FIELDS = [outgoing: MAILBOX_FIELDS - ['delete_from_server']].freeze
  CUSTOM_MAILBOX_HASH_FIELDS = [custom_mailbox: ['access_type'].freeze | INCOMING_HASH_FIELDS | OUTGOING_HASH_FIELDS].freeze
  CREATE_FIELDS = %w[name support_email default_reply_email group_id product_id
                    mailbox_type].freeze | CUSTOM_MAILBOX_HASH_FIELDS

  INDEX_FIELDS = %w[order_by order_type product_id group_id support_email forward_email active].freeze

  UPDATE_FIELDS = CREATE_FIELDS
  VALIDATABLE_DELEGATOR_ATTRIBUTES = %w[imap_mailbox_attributes
    smtp_mailbox_attributes primary_role group_id product_id].freeze

  VALIDATION_CLASS = 'Email::MailboxValidation'.freeze
  DELEGATOR_CLASS = 'Email::MailboxDelegator'.freeze
  DECORATOR_CLASS = 'Email::MailboxDecorator'.freeze

  FIELD_MAPPINGS = { reply_email: :support_email }.freeze

  MIN_CHAR_FOR_SEARCH = 3
end
