module HelperConcern
  extend ActiveSupport::Concern

  def validate_body_params(item = nil)
    params[cname].permit(*fields_to_validate)
    @validator = validation_klass.new(params[cname], item, string_request_params?)
    valid = @validator.valid?(action_name.to_sym)
    render_errors @validator.errors, @validator.error_options unless valid
    valid
  end

  def sanitize_body_params
    sanitize_bulk_action_params if bulk_action?
    prepare_array_fields(array_fields_to_sanitize.map(&:to_sym))
  end

  def validate_delegator(item = nil, options = {})
    @delegator = delegator_klass.new(item, options)
    return true if @delegator.valid?(action_name.to_sym)
    render_errors(@delegator.errors, @delegator.error_options)
    false
  end

  private

    def constants_klass
      @cklass_computed ||= (bulk_action? ? 'ApiConstants' : "#{constants_class}").constantize
    end

    def validation_klass
      @vklass_computed ||= (@validation_klass || "#{constants_class}::VALIDATION_CLASS".constantize).constantize
    end

    def delegator_klass
      @dklass_computed ||= (@delegator_klass || "#{constants_class}::DELEGATOR_CLASS".constantize).constantize
    end

    def fields_to_validate
      fields = constants_klass.const_get("#{action_name.upcase}_FIELDS")
      bulk_action? ? (fields | ApiConstants::BULK_ACTION_FIELDS) : fields
    end

    def array_fields_to_sanitize
      array_fields = "#{action_name.upcase}_ARRAY_FIELDS"
      constants_klass.const_defined?(array_fields) ? constants_klass.const_get(array_fields) : []
    end

    def bulk_action?
      ApiConstants::BULK_ACTION_METHODS.include?(action_name.to_sym)
    end
end