#Module is used to escape the html tags while rendering the page.
#Only field values that are being escaped are single line and multi line.
module Sanitize::FieldValues
  
  DEFAULT_UNSANITIZED_FIELDS_BY_OBJECT_TYPE = {"Helpdesk::Ticket" => ["subject"]}

  def sanitize_field_values_for_substitution object
    sanitize_field_values_for_object object
    sanitize_field_values_for_object object.requester if object.respond_to?('requester')
    sanitize_field_values_for_object object.company if object.respond_to?('company')
  end

  private
    def sanitize_field_values_for_object object
      return if !object 
      fields_to_be_sanitized = get_fields_to_be_sanitized object
      unless fields_to_be_sanitized.blank?
        fields_to_be_sanitized.each do |field|
          object.send "#{field}=", h(object.send(field)) #Call the set method.
        end
      end
    end

    def get_fields_to_be_sanitized object
      default_fields = DEFAULT_UNSANITIZED_FIELDS_BY_OBJECT_TYPE.fetch(object.class.name, [])
      custom_fields  = custom_fields object
      return (default_fields + custom_fields)
    end

    def custom_fields object
      if object.class.name == 'User' && object.agent?
        []
      else
        object.respond_to?('text_ff_aliases') ? object.text_ff_aliases : []
      end
    end

end