module NoteConstants
  # ControllerConstants
  REPLY_NOTE_FIELDS = ['body', 'body_html', 'user_id', { 'cc_emails' => [String] }, { 'bcc_emails' => [String] }, 'ticket_id', { 'attachments' => [ApiConstants::UPLOADED_FILE_TYPE] }]
  CREATE_NOTE_FIELDS = ['body', 'body_html', 'private', 'incoming', 'user_id', { 'notify_emails' => [String] }, 'ticket_id', { 'attachments' => [ApiConstants::UPLOADED_FILE_TYPE] }]
  UPDATE_NOTE_FIELDS = ['body', 'body_html', { 'attachments' => [] }]
  MAX_INCLUDE = 10
  NOTE_TYPE_FOR_ACTION = {
    'create' => Helpdesk::Note::SOURCE_KEYS_BY_TOKEN['note'],
    'reply'  => Helpdesk::Note::SOURCE_KEYS_BY_TOKEN['email']
  }
end
