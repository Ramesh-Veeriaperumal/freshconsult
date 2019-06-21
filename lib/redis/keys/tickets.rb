module Redis::Keys::Tickets

  HELPDESK_TICKET_FILTERS                 = "HELPDESK_TICKET_FILTERS:%{account_id}:%{user_id}:%{session_id}".freeze
  EXPORT_TICKET_FIELDS                    = "EXPORT_TICKET_FIELDS:%{account_id}:%{user_id}:%{session_id}".freeze
  HELPDESK_REPLY_DRAFTS                   = "HELPDESK_REPLY_DRAFTS:%{account_id}:%{user_id}:%{ticket_id}".freeze
  HELPDESK_TICKET_ADJACENTS               = "HELPDESK_TICKET_ADJACENTS:%{account_id}:%{user_id}:%{session_id}".freeze
  HELPDESK_TICKET_ADJACENTS_META          = "HELPDESK_TICKET_ADJACENTS_META:%{account_id}:%{user_id}:%{session_id}".freeze
  HELPDESK_TICKET_UPDATED_NODE_MSG        = "{\"account_id\":%{account_id},\"ticket_id\":%{ticket_id},\"agent\":\"%{agent_name}\",\"type\":\"%{type}\"}".freeze
  HELPDESK_ARCHIVE_TICKET_FILTERS         = "HELPDESK_ARCHIVE_TICKET_FILTERS:%{account_id}:%{user_id}:%{session_id}".freeze
  HELPDESK_ARCHIVE_TICKET_ADJACENTS       = "HELPDESK_ARCHIVE_TICKET_ADJACENTS:%{account_id}:%{user_id}:%{session_id}".freeze
  HELPDESK_ARCHIVE_TICKET_ADJACENTS_META  = "HELPDESK_ARCHIVE_TICKET_ADJACENTS_META:%{account_id}:%{user_id}:%{session_id}".freeze
  RIAK_FAILED_TICKET_CREATION             = "RIAK:FAILED_TICKET_CREATION".freeze
  RIAK_FAILED_TICKET_DELETION             = "RIAK:FAILED_TICKET_DELETION".freeze
  RIAK_FAILED_NOTE_CREATION               = "RIAK:FAILED_NOTE_CREATION".freeze
  RIAK_FAILED_NOTE_DELETION               = "RIAK:FAILED_NOTE_DELETION".freeze
  REPORT_TICKET_FILTERS                   = "REPORT_TICKET_FILTERS:%{account_id}:%{user_id}:%{session_id}:%{report_type}".freeze
  ARTICLE_FEEDBACK_FILTER                 = "ARTICLE_FEEDBACK_FILTER:%{account_id}:%{user_id}:%{session_id}".freeze
  UNDO_SEND_TIMER                         = 'UNDO_SEND_TIMER:%{account_id}'.freeze
end