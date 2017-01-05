module ConversationConstants
  # ControllerConstants
  CREATE_ARRAY_FIELDS = ['notify_emails', 'attachments', 'attachment_ids'].freeze
  REPLY_ARRAY_FIELDS = %w(cc_emails bcc_emails attachments attachment_ids).freeze
  FORWARD_ARRAY_FIELDS = %w(to_emails cc_emails bcc_emails attachments attachment_ids cloud_file_ids).freeze
  UPDATE_ARRAY_FIELDS = %w(attachments attachment_ids).freeze
  TWEET_ARRAY_FIELDS = [].freeze

  REPLY_FIELDS = %w(body full_text user_id from_email send_survey).freeze | REPLY_ARRAY_FIELDS | AttachmentConstants::CLOUD_FILE_FIELDS
  FORWARD_FIELDS = %w(body full_text agent_id from_email include_quoted_text include_original_attachments).freeze | FORWARD_ARRAY_FIELDS | AttachmentConstants::CLOUD_FILE_FIELDS
  CREATE_FIELDS = %w(body private incoming user_id).freeze | CREATE_ARRAY_FIELDS | AttachmentConstants::CLOUD_FILE_FIELDS
  TWEET_FIELDS = %w(body tweet_type twitter_handle_id).freeze
  UPDATE_FIELDS = %w(body).freeze | UPDATE_ARRAY_FIELDS | AttachmentConstants::CLOUD_FILE_FIELDS
  FACEBOOK_REPLY_FIELDS = %w(body agent_id note_id).freeze
  MAX_INCLUDE = 10
  TYPE_FOR_ACTION = {
    'create' => Helpdesk::Note::SOURCE_KEYS_BY_TOKEN['note'],
    'reply'  => Helpdesk::Note::SOURCE_KEYS_BY_TOKEN['email'],
    'forward'  => Helpdesk::Note::SOURCE_KEYS_BY_TOKEN['forward_email'],
    'facebook_reply' => Helpdesk::Note::SOURCE_KEYS_BY_TOKEN['facebook'],
    'tweet'  => Helpdesk::Note::SOURCE_KEYS_BY_TOKEN['twitter']
  }.freeze
  LOAD_OBJECT_EXCEPT = [:ticket_conversations, :reply, :forward, :facebook_reply, :tweet, :reply_template, :forward_template].freeze

  ATTRIBUTES_TO_BE_STRIPPED = %w(notify_emails to_emails cc_emails bcc_emails).freeze

  # Denotes the email fields in notes.
  EMAIL_FIELDS = [:notify_emails, :to_emails, :cc_emails, :bcc_emails].freeze

  # Wrap parameters args
  WRAP_PARAMS = [:conversation, exclude: [], format: [:json, :multipart_form]].freeze

  ALLOWED_CONTENT_TYPE_FOR_ACTION = {
    create: [:json, :multipart_form],
    update: [:json, :multipart_form],
    reply: [:json, :multipart_form],
    forward: [:json, :multipart_form]
  }.freeze

  ERROR_FIELD_MAPPINGS = { notable_id: :ticket_id, user: :user_id }
  AGENT_USER_MAPPING = { user: :agent_id }

  PARAMS_MAPPINGS = { notify_emails: :to_emails, agent_id: :user_id }
  PARAMS_TO_SAVE_AND_REMOVE = [:note_id, :cloud_files, :attachment_ids, :cloud_file_ids, :include_quoted_text, :include_original_attachments, :tweet_type, :twitter_handle_id].freeze
  PARAMS_TO_REMOVE = [:body, :full_text].freeze

  TICKET_LOAD_REQUIRED = [:create, :reply, :forward, :ticket_conversations, :facebook_reply, :tweet, :reply_template, :forward_template].freeze
  
  VALIDATION_CLASS = 'ConversationValidation'.freeze
  DELEGATOR_CLASS = 'ConversationDelegator'.freeze
  CARRIAGE_RETURN = "\r"
end.freeze
