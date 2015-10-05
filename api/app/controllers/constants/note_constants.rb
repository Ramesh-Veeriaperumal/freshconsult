module NoteConstants
  # ControllerConstants
  REPLY_FIELDS = ['body', 'body_html', 'user_id', 'cc_emails', 'bcc_emails', 'attachments', { 'cc_emails' => [] }, { 'bcc_emails' => [] }, { 'attachments' => [] }]
  CREATE_FIELDS = ['body', 'body_html', 'private', 'incoming', 'user_id', 'notify_emails', 'attachments', { 'notify_emails' => [] }, { 'attachments' => [] }]
  UPDATE_FIELDS = ['body', 'body_html', 'attachments', { 'attachments' => [] }]
  MAX_INCLUDE = 10
  TYPE_FOR_ACTION = {
    'create' => Helpdesk::Note::SOURCE_KEYS_BY_TOKEN['note'],
    'reply'  => Helpdesk::Note::SOURCE_KEYS_BY_TOKEN['email']
  }
  LOAD_OBJECT_EXCEPT = [:ticket_notes, :reply]

  FIELDS_TO_BE_STRIPPED = %w(notify_emails cc_emails bcc_emails)

  CREATE_ARRAY_FIELDS = %w(notify_emails)
  REPLY_ARRAY_FIELDS = %w(cc_emails bcc_emails)
end
