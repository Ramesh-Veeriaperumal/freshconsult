module Redis::Keys::DisplayId
  
  TICKET_DISPLAY_ID = "TICKET_DISPLAY_ID:%{account_id}".freeze
  DISPLAY_ID_LOCK   = "DISPLAY_ID_LOCK:%{account_id}".freeze
end