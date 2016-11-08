class SearchValidationHelper
  class << self
    def ticket_field_names
      ticket_custom_fields.each_with_object({}) { |ticket_field, hash| hash[ticket_field.name] = TicketDecorator.display_name(ticket_field.name) }
    end

    def ticket_field_column_names
      ticket_custom_fields.each_with_object({}) { |ticket_field, hash| hash[TicketDecorator.display_name(ticket_field.name).to_sym] = ticket_field.column_name }
    end

    def ticket_custom_fields
    	ticket_fields.select{|x| ApiSearchConstants::ALLOWED_CUSTOM_FIELD_TYPES.include? x.field_type }
    end

    def ticket_fields
      Account.current.ticket_fields_from_cache
    end

    def contact_field_names
      contact_custom_fields.each_with_object({}) { |field, hash| hash[field.name] =  CustomFieldDecorator.display_name(field.name) }
    end

    def contact_field_column_names
      contact_custom_fields.each_with_object({}) { |field, hash| hash[CustomFieldDecorator.display_name(field.name).to_sym] = field.column_name }
    end

    def contact_custom_fields
      contact_fields.select{|x| ApiSearchConstants::ALLOWED_CUSTOM_FIELD_TYPES.include? x.field_type.to_s }
    end

    def contact_fields
      Account.current.contact_form.contact_fields_from_cache
    end

    def company_field_names
      company_custom_fields.each_with_object({}) { |field, hash| hash[field.name] =  CustomFieldDecorator.display_name(field.name) }
    end

    def company_field_column_names
      company_custom_fields.each_with_object({}) { |field, hash| hash[CustomFieldDecorator.display_name(field.name).to_sym] = field.column_name }
    end

    def company_custom_fields
      company_fields.select{|x| ApiSearchConstants::ALLOWED_CUSTOM_FIELD_TYPES.include? x.field_type.to_s }
    end

    def company_fields
      Account.current.company_form.company_fields_from_cache
    end
  end
end
