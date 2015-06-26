class Helpers::TicketsValidation
  class << self
    def ticket_status_values(account)
      account ? Helpdesk::TicketStatus.status_keys_by_name(account).values : []
    end

    def ticket_type_values(account)
      account ? account.ticket_types_from_cache.collect(&:value) : []
    end

    def ticket_custom_field_keys(account)
      account ? account.flexifields_with_ticket_fields_from_cache.collect(&:flexifield_alias) : []
    end
  end
end
