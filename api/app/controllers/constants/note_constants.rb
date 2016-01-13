module NoteConstants
  # ControllerConstants
  CREATE_ARRAY_FIELDS = ['notify_emails', 'attachments'].freeze
  REPLY_ARRAY_FIELDS = %w(cc_emails bcc_emails attachments).freeze
  UPDATE_ARRAY_FIELDS = ['attachments'].freeze

  REPLY_FIELDS = %w(body body_html user_id cc_emails bcc_emails attachments).freeze | REPLY_ARRAY_FIELDS.map { |x| Hash[x, [nil]] }
  CREATE_FIELDS = %w(body body_html private incoming user_id notify_emails attachments).freeze | CREATE_ARRAY_FIELDS.map { |x| Hash[x, [nil]] }
  UPDATE_FIELDS = %w(body body_html attachments).freeze | UPDATE_ARRAY_FIELDS.map { |x| Hash[x, [nil]] }
  MAX_INCLUDE = 10
  TYPE_FOR_ACTION = {
    'create' => Helpdesk::Note::SOURCE_KEYS_BY_TOKEN['note'],
    'reply'  => Helpdesk::Note::SOURCE_KEYS_BY_TOKEN['email']
  }.freeze
  LOAD_OBJECT_EXCEPT = [:ticket_notes, :reply].freeze

  ATTRIBUTES_TO_BE_STRIPPED = %w(notify_emails cc_emails bcc_emails).freeze

  # Denotes the email fields in notes.
  EMAIL_FIELDS = [:notify_emails, :cc_emails, :bcc_emails].freeze

  # Wrap parameters args
  WRAP_PARAMS = [:note, exclude: [], format: [:json, :multipart_form]].freeze

  ALLOWED_CONTENT_TYPE_FOR_ACTION = {
    create: [:json, :multipart_form],
    update: [:json, :multipart_form],
    reply: [:json, :multipart_form]
  }.freeze
end.freeze
