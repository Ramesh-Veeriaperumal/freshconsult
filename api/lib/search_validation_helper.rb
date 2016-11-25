class SearchValidationHelper
  class << self
    def ticket_field_names
      searchable_custom_fields.each_with_object({}) { |ticket_field, hash| hash[ticket_field.name] = TicketDecorator.display_name(ticket_field.name) }
    end

    def ticket_field_column_names
      searchable_custom_fields.each_with_object({}) { |ticket_field, hash| hash[TicketDecorator.display_name(ticket_field.name).to_sym] = ticket_field.column_name }
    end

    def searchable_custom_fields
    	Account.current.ticket_fields_from_cache.select{|x| ApiSearchConstants::ALLOWED_TICKET_FIELD_TYPES.include? x.field_type }
    end
  end
end
