module ConversationConstants
  # ControllerConstants
  CREATE_ARRAY_FIELDS = ['notify_emails', 'attachments', 'attachment_ids', 'inline_attachment_ids'].freeze
  REPLY_ARRAY_FIELDS = %w(cc_emails bcc_emails attachments attachment_ids inline_attachment_ids).freeze
  FORWARD_ARRAY_FIELDS = %w(to_emails cc_emails bcc_emails attachments attachment_ids cloud_file_ids inline_attachment_ids).freeze
  UPDATE_ARRAY_FIELDS = %w(attachments attachment_ids inline_attachment_ids).freeze
  TWEET_ARRAY_FIELDS = [].freeze

  IGNORE_PARAMS = %w(full_text send_survey last_note_id inline_attachment_ids).freeze | AttachmentConstants::CLOUD_FILE_FIELDS

  TICKET_CONVERSATIONS_FIELDS = %w(include order_type since_id).freeze
  SIDE_LOADING = %w(requester).freeze
  PERMITTED_ARCHIVE_FIELDS = (TICKET_CONVERSATIONS_FIELDS + ApiConstants::PAGINATE_FIELDS).freeze

  REPLY_FIELDS = %w[body full_text user_id from_email send_survey last_note_id include_surveymonkey_link post_to_forum_topic reply_ticket_id].freeze | REPLY_ARRAY_FIELDS | AttachmentConstants::CLOUD_FILE_FIELDS
  BROADCAST_FIELDS = %w(body user_id inline_attachment_ids).freeze
  REPLY_TO_FORWARD_FIELDS = %w(body full_text user_id from_email to_emails send_survey).freeze | REPLY_ARRAY_FIELDS | AttachmentConstants::CLOUD_FILE_FIELDS
  FORWARD_FIELDS = %w(body full_text agent_id from_email include_quoted_text include_original_attachments).freeze | FORWARD_ARRAY_FIELDS | AttachmentConstants::CLOUD_FILE_FIELDS

  CREATE_FIELDS = %w(body private incoming user_id last_note_id).freeze | CREATE_ARRAY_FIELDS | AttachmentConstants::CLOUD_FILE_FIELDS
  TWEET_FIELDS = %w[body tweet_type twitter_handle_id last_note_id attachment_ids include_surveymonkey_link].freeze
  UPDATE_FIELDS = %w(body).freeze | UPDATE_ARRAY_FIELDS | AttachmentConstants::CLOUD_FILE_FIELDS
  FACEBOOK_REPLY_FIELDS = %w[body agent_id note_id last_note_id attachment_ids msg_type include_surveymonkey_link].freeze
  ECOMMERCE_REPLY_FIELDS = %w[body agent_id last_note_id attachment_ids].freeze
  CHANNEL_REPLY_FIELDS = %w[body channel_id last_note_id profile_unique_id].freeze
  MAX_INCLUDE = 10
  TYPE_FOR_ACTION = {
    'create' => Helpdesk::Source.note_source_keys_by_token['note'],
    'reply'  => Helpdesk::Source.note_source_keys_by_token['email'],
    'reply_to_forward' => Helpdesk::Source.note_source_keys_by_token['note'],
    'forward' => Helpdesk::Source.note_source_keys_by_token['forward_email'],
    'facebook_reply' => Helpdesk::Source.note_source_keys_by_token['facebook'],
    'ecommerce_reply' => Helpdesk::Source.note_source_keys_by_token['ecommerce'],
    'tweet' => Helpdesk::Source.note_source_keys_by_token['twitter'],
    'broadcast' => Helpdesk::Source.note_source_keys_by_token['note']
  }.freeze

  PUBLIC_API_DEFAULT_FIELDS = %w[body user_id attachments].freeze
  PUBLIC_API_FIELDS = {
    Helpdesk::Source.ticket_source_keys_by_token[:facebook] => %w[parent_note_id].freeze | PUBLIC_API_DEFAULT_FIELDS,
    Helpdesk::Source.ticket_source_keys_by_token[:twitter] => [twitter: [:tweet_type, :twitter_handle_id]].freeze | PUBLIC_API_DEFAULT_FIELDS
  }.freeze

  PIPE_REPLY_FIELDS  = REPLY_FIELDS | %w(created_at updated_at)
  PIPE_CREATE_FIELDS = CREATE_FIELDS | %w(created_at updated_at)
  CATEGORY = {
    'reply_to_forward' => 6, # Used for conversation with third party
  }.freeze
  LOAD_OBJECT_EXCEPT = %i(ticket_conversations create reply forward broadcast
                          reply_to_forward facebook_reply tweet reply_template ecommerce_reply forward_template
                          latest_note_forward_template undo_send channel_reply).freeze

  ATTRIBUTES_TO_BE_STRIPPED = %w(notify_emails to_emails cc_emails bcc_emails).freeze

  # Denotes the email fields in notes.
  EMAIL_FIELDS = [:notify_emails, :to_emails, :cc_emails, :bcc_emails].freeze

  # Wrap parameters args
  WRAP_PARAMS = [:conversation, exclude: [], format: [:json, :multipart_form]].freeze

  ALLOWED_CONTENT_TYPE_FOR_ACTION = {
    create: %i(json multipart_form),
    update: %i(json multipart_form),
    reply: %i(json multipart_form),
    forward: %i(json multipart_form),
    reply_to_forward: %i(json multipart_form)
  }.freeze

  ERROR_FIELD_MAPPINGS = { notable_id: :ticket_id, user: :user_id }.freeze
  AGENT_USER_MAPPING = { user: :agent_id }.freeze

  PARAMS_MAPPINGS = { notify_emails: :to_emails, agent_id: :user_id, name: :filename }.freeze
  PARAMS_TO_SAVE_AND_REMOVE = [:note_id, :cloud_files, :attachment_ids, :cloud_file_ids, :include_quoted_text, :include_original_attachments, :tweet_type, :twitter_handle_id, :inline_attachment_ids, :msg_type, :reply_ticket_id, :channel_id, :profile_unique_id].freeze
  PARAMS_TO_REMOVE = [:body, :full_text].freeze

  TICKET_LOAD_REQUIRED = %i[create reply forward reply_to_forward ticket_conversations facebook_reply tweet ecommerce_reply reply_template forward_template latest_note_forward_template broadcast channel_reply].freeze

  TICKET_STATE_CHECK_NOT_REQUIRED = [:ticket_conversations].freeze

  VALIDATION_CLASS = 'ConversationValidation'.freeze
  DELEGATOR_CLASS = 'ConversationDelegator'.freeze
  CARRIAGE_RETURN = "\r".freeze
end.freeze
