module HelperConcern
  extend ActiveSupport::Concern

  def validate_body_params(item = nil, params_hash = nil)
    validate_request(item, params[cname], params_hash)
  end

  def validate_query_params(item = nil, params_hash = nil)
    validate_request(item, params, params_hash, true)
  end

  def sanitize_body_params
    sanitize_bulk_action_params if bulk_action?
    prepare_array_fields(array_fields_to_sanitize.map(&:to_sym))
  end

  def validate_delegator(item = nil, options = {})
    @delegator = delegator_klass.new(item, options)
    return true if @delegator.valid?(action_name.to_sym)
    render_custom_errors(@delegator, true)
    false
  end

  private

    def validate_request(item, request_params, params_hash, url_params = false)
      default_fields = url_params ? fetch_default_params : []
      request_params.permit(*fields_to_validate, *default_fields)
      @validator = validation_klass.new(params_hash || request_params, item, string_request_params?)
      valid = @validator.valid?(action_name.to_sym)
      render_custom_errors(@validator, true) unless valid
      valid
    end

    def constants_klass
      @cklass_computed ||= (@constants_klass || constants_class.to_s).constantize
    end

    def validation_klass
      @vklass_computed ||= (@validation_klass || "#{constants_class}::VALIDATION_CLASS".constantize).constantize
    end

    def delegator_klass
      @dklass_computed ||= (@delegator_klass || "#{constants_class}::DELEGATOR_CLASS".constantize).constantize
    end

    def fields_to_validate
      field_string = "#{action_name.upcase}_FIELDS"
      fields = constants_klass.const_defined?(field_string) ? constants_klass.const_get(field_string) : []
      bulk_action? ? (fields | ApiConstants::BULK_ACTION_FIELDS) : fields
    end

    def fetch_default_params
      index? ? ApiConstants::DEFAULT_INDEX_FIELDS : ApiConstants::DEFAULT_PARAMS
    end

    def array_fields_to_sanitize
      array_fields = "#{action_name.upcase}_ARRAY_FIELDS"
      constants_klass.const_defined?(array_fields) ? constants_klass.const_get(array_fields) : []
    end

    def bulk_action?
      ApiConstants::BULK_ACTION_METHODS.include?(action_name.to_sym)
    end
end
