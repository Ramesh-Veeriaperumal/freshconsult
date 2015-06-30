module NoteConstants
  # *********************************-- ControllerConstants --*********************************************
  REPLY_NOTE_FIELDS = ['body', 'body_html', 'user_id', { 'cc_emails' => [String] }, { 'bcc_emails' => [String] }, 'ticket_id', { 'attachments' => [ApiConstants::UPLOADED_FILE_TYPE] }]
  CREATE_NOTE_FIELDS = ['body', 'body_html', 'private', 'incoming', 'user_id', { 'notify_emails' => [String] }, 'ticket_id', { 'attachments' => [ApiConstants::UPLOADED_FILE_TYPE] }]
  UPDATE_NOTE_FIELDS = ['body', 'body_html', { 'attachments' => [] }]
  NOTE_TYPE_FOR_ACTION = {
    'create' => Helpdesk::Note::SOURCE_KEYS_BY_TOKEN['note'],
    'reply'  => Helpdesk::Note::SOURCE_KEYS_BY_TOKEN['email']
  }

  NOTE_SOURCE_SCOPE = {
    'update' => Helpdesk::Note::SOURCE_KEYS_BY_TOKEN.slice('email', 'note').values,
    'destroy' => Helpdesk::Note::SOURCE_KEYS_BY_TOKEN.slice('email', 'note').values
  }
end
