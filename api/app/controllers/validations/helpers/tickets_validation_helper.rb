class Helpers::TicketsValidationHelper
  class << self
    def ticket_status_values
      Account.current ? Helpdesk::TicketStatus.status_keys_by_name(Account.current).values : []
    end

    def ticket_type_values
      Account.current ? Account.current.ticket_types_from_cache.collect(&:value) : []
    end

    def ticket_custom_field_keys
      Account.current ? Account.current.flexifields_with_ticket_fields_from_cache.collect(&:flexifield_alias) : []
    end

    def attachment_size(item)
      item.try(:attachments).try(:sum, &:content_file_size).to_i
    end
  end
end
