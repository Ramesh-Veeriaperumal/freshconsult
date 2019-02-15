module MultipleValidationConcern
  extend ActiveSupport::Concern

  def request_multiple_validation(validation_klasses)
    valid = true
    validation_klasses.each do |validation_klass_name|
      klass_name_snake_cased = validation_klass_name.demodulize.underscore
      item = try_method("#{klass_name_snake_cased}_item")
      request_params = try_method("#{klass_name_snake_cased}_request_params")
      params_hash = try_method("#{klass_name_snake_cased}_params_hash")
      permit_params = permit_params_wrapper("#{klass_name_snake_cased}_permit_params?")
      valid = validate_request(item, request_params, params_hash, validation_klass_name, permit_params)
      break unless valid
    end
    valid
  end

  def request_multiple_delegator_validation(delegator_klasses)
    valid = true
    delegator_klasses.each do |delegator_klass_name|
      klass_name_snake_cased = delegator_klass_name.demodulize.underscore
      item = try_method("#{klass_name_snake_cased}_item")
      options = try_method("#{klass_name_snake_cased}_options")
      valid = validate_delegator(delegator_klass_name, item, options)
      break unless valid
    end
    valid
  end

  def validate_delegator(klass_name, item = nil, options = {})
    @delegator = delegator_klass(klass_name).new(item, options)
    return true if @delegator.valid?(action_name.to_sym)
    render_custom_errors(@delegator, true)
    false
  end

  def validate_request(item, request_params, params_hash, klass_name, permit_params = true, url_params = false)
    if permit_params
      default_fields = url_params ? fetch_default_params : []
      request_params.permit(*fields_to_validate(klass_name), *default_fields)
    end
    @validator = validation_klass(klass_name).new(params_hash || request_params, item, string_request_params?)
    valid = @validator.valid?(action_context(klass_name) || action_name.to_sym)
    render_custom_errors(@validator, true) unless valid
    valid
  end

  def action_context(klass_name)
    method_name = "#{klass_name.demodulize.underscore}_action"
    try_method(method_name)
  end

  def try_method(method_name)
    self.class.method_defined?(method_name) ? safe_send(method_name) : nil
  end

  def permit_params_wrapper(method_name)
    is_permit = try_method(method_name)
    is_permit.nil? ? true : is_permit
  end

  def fields_to_validate(klass_name)
    fields = safe_send("#{klass_name.demodulize.underscore}_fields")
    fields ? fields : []
  end

  def fetch_default_params
    index? ? ApiConstants::DEFAULT_INDEX_FIELDS : ApiConstants::DEFAULT_PARAMS
  end

  def validation_klass(klass_name)
    klass_name.constantize
  end
  alias delegator_klass validation_klass
end
