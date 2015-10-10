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
    def assign_checkbox_value(custom_fields, fields)
      check_box_names = fields.select { |x| x.field_type.to_sym == :custom_checkbox }.map(&:name)
      custom_fields.each_pair do |key, value|
        next unless check_box_names.include?(key.to_s)
        custom_fields[key] = 0 if value.is_a?(FalseClass) || value == 'false'
      end
    end
  end
end
