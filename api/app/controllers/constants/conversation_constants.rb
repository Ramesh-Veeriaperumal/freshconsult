module ConversationConstants
  # ControllerConstants
  CREATE_ARRAY_FIELDS = ['notify_emails', 'attachments', 'attachment_ids'].freeze
  REPLY_ARRAY_FIELDS = %w(cc_emails bcc_emails attachments attachment_ids).freeze
  UPDATE_ARRAY_FIELDS = ['attachments'].freeze

  REPLY_FIELDS = %w(body user_id from_email).freeze | REPLY_ARRAY_FIELDS
  CREATE_FIELDS = %w(body private incoming user_id).freeze | CREATE_ARRAY_FIELDS
  UPDATE_FIELDS = %w(body).freeze | UPDATE_ARRAY_FIELDS
  MAX_INCLUDE = 10
  TYPE_FOR_ACTION = {
    'create' => Helpdesk::Note::SOURCE_KEYS_BY_TOKEN['note'],
    'reply'  => Helpdesk::Note::SOURCE_KEYS_BY_TOKEN['email']
  }.freeze
  LOAD_OBJECT_EXCEPT = [:ticket_conversations, :reply].freeze

  ATTRIBUTES_TO_BE_STRIPPED = %w(notify_emails cc_emails bcc_emails).freeze

  # Denotes the email fields in notes.
  EMAIL_FIELDS = [:notify_emails, :cc_emails, :bcc_emails].freeze

  # Wrap parameters args
  WRAP_PARAMS = [:conversation, exclude: [], format: [:json, :multipart_form]].freeze

  ALLOWED_CONTENT_TYPE_FOR_ACTION = {
    create: [:json, :multipart_form],
    update: [:json, :multipart_form],
    reply: [:json, :multipart_form]
  }.freeze
end.freeze
