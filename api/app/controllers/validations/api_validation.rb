class ApiValidation
  include ActiveModel::Validations
  include ActiveModel::Validations::Callbacks
  attr_accessor :error_options, :allow_string_param, :ids, :attachment_ids, :skip_bulk_validations, :skip_hash_params_set, :skip_hash_params_set_for_parameters

  before_validation :trim_attributes
  validates :ids, required: true, data_type: { rules: Array, allow_nil: false },
                  array: { custom_numericality: { only_integer: true, greater_than: 0, allow_nil: false, ignore_string: :allow_string_param } },
                  custom_length: { maximum: ApiConstants::MAX_ITEMS_FOR_BULK_ACTION, message_options: { element_type: :values } }, if: :is_bulk_action?, unless: :skip_bulk_validations
  validates :attachment_ids, data_type: { rules: Array, allow_nil: false }, array: { custom_numericality: { only_integer: true, greater_than: 0, allow_nil: false, ignore_string: :allow_string_param } }

  FORMATTED_TYPES = [ActiveSupport::TimeWithZone].freeze
  CHECK_PARAMS_SET_FIELDS = [].freeze
  CREATE_AND_UPDATE_ACTIONS = %i[create update].freeze

  # Set instance variables of validation class from request params or items. so that manual assignment is not needed.
  def initialize(request_params, item = nil, allow_string_param = false, model_decorator = nil)
    # Set instance variables of validation class from loaded item's attributes (incase of PUT/update request)
    @request_params = request_params

    if item
      if model_decorator
        assign_model_attributes(model_decorator.new(item).attribute_values)
      else
        item.attributes.keys.each do |field, value|
          safe_send("#{field}=", format_value(item.safe_send(field))) if respond_to?("#{field}=")
        end
      end
    end

    # Set instance variables of validation class from the request params.
    set_instance_variables(request_params)

    # Allow string param based on action & content_type
    @allow_string_param = allow_string_param
    @error_options = {}
    check_params_set(request_params.slice(*self.class::CHECK_PARAMS_SET_FIELDS)) if self.class::CHECK_PARAMS_SET_FIELDS.any?
  end

  # Set true for instance_variable_set if it is part of request params.
  # Say if request params has forum_type, forum_type_set attribute will be set to true.
  def check_params_set(request_params)
    request_params.each_pair do |key, value|
      instance_variable_set("@#{key}_set", true)
      check_params_set(value) if value.is_a?(Hash)
    end
  end

  def fill_custom_fields(request_params, custom_fields)
    if !request_params.key?(:custom_fields)
      @custom_fields = custom_fields.reject { |k, v| v.nil? }
    elsif request_params[:custom_fields].is_a?(Hash)
      @custom_fields = custom_fields.reject { |k, v| v.nil? }.merge(request_params[:custom_fields])
    end
  end

  def format_value(value)
    (FORMATTED_TYPES.include?(value.class) ? value.iso8601 : value)
  end

  def trim_attributes
    attributes_to_be_stripped.each do |x|
      attribute = safe_send(x)
      next if attribute.nil?
      if attribute.respond_to?(:strip!)
        attribute.strip!
      elsif attribute.is_a?(Array)
        attribute.each { |element| strip_attribute(element) }
      elsif attribute.is_a?(Hash)
        attribute.each { |key, value| strip_attribute(value) }
      end
    end
  end

  def strip_attribute(attribute)
    attribute.strip! if attribute.respond_to?(:strip!)
  end

  def attributes_to_be_stripped
    []
  end

  def set_instance_variables(request_params)
    request_params.each_pair do |key, value|
      if respond_to?("#{key}=")
        safe_send("#{key}=", value)
      else
        instance_variable_set("@#{key}", value)
      end
      set_instance_variables(value) if value.is_a?(Hash) && !(skip_hash_params_set || skip_hash_params_set_for_parameters.try(:include?, key))
    end
  end

  def assign_model_attributes(attribute_hash)
    attribute_hash.each_pair do |field, value|
      safe_send("#{field}=", format_value(value)) if respond_to?("#{field}=")
      assign_model_attributes(value) if value.is_a?(Hash) && !(skip_hash_params_set || skip_hash_params_set_for_parameters.try(:include?, field))
    end
  end

  def is_bulk_action?
    ApiConstants::BULK_ACTION_METHODS.include?(validation_context)
  end

  ["create", "update"].each do |action|
    define_method("#{action}?") do
      action.to_sym == validation_context
    end
  end

  def validate_query_hash
    return unless query_hash.present? && query_hash.is_a?(Array)
    query_hash.each_with_index do |query, index|
      query_hash_validator = ::QueryHashValidation.new(query)
      next if query_hash_validator.valid?
      message = ErrorHelper.format_error(query_hash_validator.errors, query_hash_validator.error_options)
      messages = message.is_a?(Array) ? message : [message]
      errors[:"query_hash[#{index}]"] = messages.map { |m| "#{m.field}: #{m.message}" }.join(' & ')
    end
  end

  def attachment_limit
    @attachment_limit ||= (Account.current.attachment_limit.megabytes)
  end

  private

    def private_api?
      CustomRequestStore.read(:private_api_request)
    end

    def create_or_update?
      CREATE_AND_UPDATE_ACTIONS.include?(validation_context)
    end

    def destroy?
      validation_context == :destroy
    end
end
