module NoteConstants
  # ControllerConstants
  CREATE_ARRAY_FIELDS = ['notify_emails', 'attachments' ]
  REPLY_ARRAY_FIELDS = ['cc_emails', 'bcc_emails', 'attachments']
  UPDATE_ARRAY_FIELDS = ['attachments']
  
  REPLY_FIELDS = ['body', 'body_html', 'user_id', 'cc_emails', 'bcc_emails', 'attachments'] | REPLY_ARRAY_FIELDS.map{|x| Hash[x, [nil]]}
  CREATE_FIELDS = ['body', 'body_html', 'private', 'incoming', 'user_id', 'notify_emails', 'attachments'] | CREATE_ARRAY_FIELDS.map{|x| Hash[x, [nil]]}
  UPDATE_FIELDS = ['body', 'body_html', 'attachments'] | UPDATE_ARRAY_FIELDS.map{|x| Hash[x, [nil]]}
  MAX_INCLUDE = 10
  TYPE_FOR_ACTION = {
    'create' => Helpdesk::Note::SOURCE_KEYS_BY_TOKEN['note'],
    'reply'  => Helpdesk::Note::SOURCE_KEYS_BY_TOKEN['email']
  }
  LOAD_OBJECT_EXCEPT = [:ticket_notes, :reply]

  FIELDS_TO_BE_STRIPPED = %w(notify_emails cc_emails bcc_emails)

  # Wrap parameters args
  WRAP_PARAMS = [:note, exclude: [], format: [:json, :multipart_form]]

  ALLOWED_CONTENT_TYPE_FOR_ACTION = {
    create: [:json, :multipart_form],
    update: [:json, :multipart_form],
    reply: [:json, :multipart_form]
  }
end
