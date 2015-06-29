module ApiConstants
  # *********************************-- ControllerConstants --*********************************************

  API_CURRENT_VERSION = 'v2'
  DEFAULT_PAGINATE_OPTIONS = {
    per_page: 30,
    page: 1
  }
  DEFAULT_PARAMS = [:version, :format, :k].map(&:to_s)
  DEFAULT_INDEX_FIELDS = [:per_page, :page]
  UPLOADED_FILE_TYPE = ActionDispatch::Http::UploadedFile

  # *********************************-- DiscussionConstants --*********************************************

  GROUP_FIELDS = ['name', 'description', 'escalate_to', 'unassigned_for', 'auto_ticket_assign', { 'agents' => [] }, 'agents']

  # *********************************-- TicketConstants --*********************************************

  TICKET_ARRAY_FIELDS = [{ 'tags' => [String] }, { 'cc_emails' => [String] }, { 'attachments' => [] }]
  CREATE_TICKET_FIELDS = %w(cc_emails description description_html due_by email_config_id fr_due_by group_id priority email phone twitter_id facebook_id requester_id name responder_id source status subject type product_id tags) | TICKET_ARRAY_FIELDS
  UPDATE_TICKET_FIELDS = %w(description description_html due_by email_config_id fr_due_by group_id priority email phone twitter_id facebook_id requester_id name responder_id source status subject type product_id tags) | TICKET_ARRAY_FIELDS.reject { |k| k['cc_emails'] }
  ASSIGN_TICKET_FIELDS = ['user_id']
  RESTORE_TICKET_FIELDS = []
  REPLY_NOTE_FIELDS = ['body', 'body_html', 'user_id', { 'cc_emails' => [String] }, { 'bcc_emails' => [String] }, 'ticket_id', { 'attachments' => [UPLOADED_FILE_TYPE] }]
  CREATE_NOTE_FIELDS = ['body', 'body_html', 'private', 'incoming', 'user_id', { 'notify_emails' => [String] }, 'ticket_id', { 'attachments' => [UPLOADED_FILE_TYPE] }]
  UPDATE_NOTE_FIELDS = ['body', 'body_html', { 'attachments' => [] }]
  TICKET_ORDER_TYPE = TicketsFilter::SORT_ORDER_FIELDS.map(&:first).map(&:to_s)
  TICKET_ORDER_BY = TicketsFilter::SORT_FIELDS.map(&:first).map(&:to_s)
  TICKET_FILTER = TicketsFilter::DEFAULT_VISIBLE_FILTERS.values_at(0, 2, 3, 4)
  DELETED_SCOPE = {
    'update' => false,
    'assign' => false,
    'restore' => true,
    'destroy' => false,
    'time_sheets' => false
  }

  INDEX_TICKET_FIELDS = %w(filter company_id requester_id order_by order_type created_since updated_since)
  ORDER_BY_SCOPE = {
    'index' => true,
    'notes' => false
  }

  # *********************************-- GroupConstants --**************************************************

  UNASSIGNED_FOR_MAP = { '30m' => 1800, '1h' => 3600, '2h' => 7200, '4h' => 14_400, '8h' => 28_800, '12h' => 43_200, '1d' => 86_400, '2d' => 172_800, '3d' => 259_200, nil => 1800 }

  # *********************************-- TimeSheetConstants --*********************************************

  INDEX_TIMESHEET_FIELDS = %w(company_id user_id executed_after executed_before billable group_id pp)

  # *********************************-- TicketFieldConstants --*********************************************

  TICKET_FIELD_TYPES = Helpdesk::TicketField::FIELD_CLASS.keys.map(&:to_s)

  NOTE_TYPE_FOR_ACTION = {
    'create' => Helpdesk::Note::SOURCE_KEYS_BY_TOKEN['note'],
    'reply'  => Helpdesk::Note::SOURCE_KEYS_BY_TOKEN['email']
  }

  # *********************************-- ValidationConstants --*********************************************

  BOOLEAN_VALUES = ['0', 0, false, '1', 1, true, 'true', 'false'] # for boolean fields all these values are accepted.
  EMAIL_REGEX = /\b[-a-zA-Z0-9.'’&_%+]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,15}\b/
end
