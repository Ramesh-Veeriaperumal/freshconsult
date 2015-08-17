class ParamsHelper
  class << self
    def assign_and_clean_params(params_hash, controller_params)
      # Assign original fields with api params
      params_hash.each_pair do |api_field, attr_field|
        controller_params[attr_field] = controller_params[api_field] if controller_params[api_field]
      end
      clean_params(params_hash.keys, controller_params)
    end

    def clean_params(params_to_be_deleted, controller_params)
      # Delete the fields from params before calling build or save or update_attributes
      params_to_be_deleted.each do |field|
        controller_params.delete(field)
      end
    end

    def uniq_params(params_with_uniq_value, controller_params)
      params_with_uniq_value.each do |field|
        controller_params[field].try(:uniq!)
      end
    end

    def get_user_param(email)
      email ? :email : :user_id
    end
  end
end
