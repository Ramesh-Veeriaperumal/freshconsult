module Cache
  module FragmentCache
    module Keys

      TICKETS_LIST_PAGE_FILTERS = "v1/TICKETS_LIST_PAGE_FILTERS:%{account_id}:%{language}"
      AGENT_NEW_TICKET_FORM     = "v2/AGENT_NEW_TICKET_FORM:%{account_id}:%{language}"
      COMPOSE_EMAIL_FORM        = "v2/COMPOSE_EMAIL_FORM:%{account_id}:%{language}"
      SUPPORT_NEW_TICKET_FORM   = "v1/SUPPORT_NEW_TICKET_FORM:%{account_id}:%{language}"
    end
  end
end