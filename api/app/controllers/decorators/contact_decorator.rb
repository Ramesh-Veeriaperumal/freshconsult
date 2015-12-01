class ContactDecorator
  class << self
  	def remove_prepended_text_from_contact_fields(custom_fields, custom_fields_api_name_mapping=nil)
      custom_fields_api_name_mapping ||= Account.current.contact_form.custom_contact_fields.collect{ |x| [x.name.to_sym, x.api_name.to_sym] }.to_h
      CustomFieldDecorator.remove_prepended_text_from_custom_fields(custom_fields, custom_fields_api_name_mapping)
    end
  end
end