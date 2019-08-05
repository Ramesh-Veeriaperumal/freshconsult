module EmailMailboxConstants
  PARAMS_MAPPING = {
    support_email: :reply_email,
    default_reply_email: :primary_role
  }.freeze
  ACCESS_TYPE_PARAMS_MAPPING = { mail_server: :server_name }.freeze
  PARAMS_TO_DELETE = %i[mailbox_type freshdesk_mailbox custom_mailbox].freeze
  CREATE_FIELDS = %w[name support_email default_reply_email group_id product_id
                    mailbox_type custom_mailbox].freeze
  VALIDATION_CLASS = 'Email::MailboxValidation'.freeze
  DELEGATOR_CLASS = 'Email::MailboxDelegator'.freeze
  
  FIELD_MAPPINGS = { reply_email: :support_email }.freeze
end