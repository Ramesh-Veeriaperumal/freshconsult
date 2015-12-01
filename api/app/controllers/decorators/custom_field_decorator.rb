class CustomFieldDecorator < SimpleDelegator
  class << self
    def utc_format(cf)
      cf.each_pair { |k, v| cf[k] = v.utc if v.respond_to?(:utc) }
      cf
    end

    def remove_prepended_text_from_custom_fields(custom_fields, custom_fields_api_name_mapping)
      custom_fields_hash = {}
      custom_fields.each { |name| custom_fields_hash[custom_fields_api_name_mapping[name]] = custom_fields.delete name }
      custom_fields_hash
    end
  end
end
