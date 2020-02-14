module Cache
  module FragmentCache
    module Keys
      TICKETS_LIST_PAGE_FILTERS = 'v2/TICKETS_LIST_PAGE_FILTERS:%{account_id}:%{language}'.freeze
      AGENT_NEW_TICKET_FORM     = 'v3/AGENT_NEW_TICKET_FORM:%{account_id}:%{language}'.freeze
      COMPOSE_EMAIL_FORM        = 'v3/COMPOSE_EMAIL_FORM:%{account_id}:%{language}'.freeze
      SUPPORT_NEW_TICKET_FORM   = 'v4/SUPPORT_NEW_TICKET_FORM:%{account_id}:%{language}'.freeze
    end
  end
end
