class TicketDecorator
  class << self
  	#This method converts custom_field name to api_name and also converts the value to UTC if its date format
    def remove_appended_text_from_ticket_fields(custom_fields, custom_fields_api_name_mapping=nil)
      custom_fields_hash = {}
      custom_fields_api_name_mapping ||= Helpers::TicketsValidationHelper.custom_field_api_name_mapping(Account.current.ticket_fields_from_cache)
      custom_fields.keys.each do |name|
        custom_field_value = custom_fields.delete name
        custom_field_value = custom_field_value.utc if custom_field_value.respond_to?(:utc)
        custom_fields_hash[custom_fields_api_name_mapping[name.to_sym]] = custom_field_value
      end
      custom_fields_hash
    end
  end
end