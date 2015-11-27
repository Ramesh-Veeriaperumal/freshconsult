class ParamsHelper
  class << self
    def assign_and_clean_params(params_hash, controller_params)
      # Assign original fields with api params
      params_hash.each_pair do |api_field, attr_field|
        controller_params[attr_field] = controller_params[api_field] if controller_params.key? api_field
      end
      clean_params(params_hash.keys, controller_params)
    end

    def clean_params(params_to_be_deleted, controller_params)
      # Delete the fields from params before calling build or save or update_attributes
      params_to_be_deleted.each do |field|
        controller_params.delete(field)
      end
    end

    # If false given, nil is getting saved in db as there is nil assignment if blank in flexifield. Hence assign 0
    def assign_checkbox_value(custom_fields, check_box_names)
      custom_fields.each_pair do |key, value|
        next unless check_box_names.include?(key.to_s)
        custom_fields[key] = 0 if value.is_a?(FalseClass)
      end
    end

    def prepend_with_cf_for_custom_fields(custom_field_hash)
      rename_fields_hash = {}
      if custom_field_hash.is_a? Hash
        custom_field_hash.keys.each do | key | 
          new_key = "cf_#{key}"
          custom_field_hash[new_key] = custom_field_hash.delete key 
          rename_fields_hash[new_key.to_sym] = key.to_sym
        end
      end
      rename_fields_hash
    end
  end
end
