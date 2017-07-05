class QueryHashValidation < FilterValidation
  
  attr_accessor :condition, :operator, :value, :type

  validates :condition, required: true, data_type: { rules: String }
  validates :operator, required: true, data_type: { rules: String }, custom_inclusion: { in: CustomFilterConstants::OPERATORS }
  validates :type, data_type: { rules: String }, custom_inclusion: { in: CustomFilterConstants::QUERY_TYPE_OPTIONS }
  validates :value, required: true

  validates :value, data_type: { rules: Array }, if: -> { CustomFilterConstants::ARRAY_VALUED_OPERATORS.include?(operator) }

  validate :ticket_fields_condition
  validate :valid_params?

  def custom_field_names
    @custom_field_names ||= Account.current.ticket_fields_from_cache
      .select { |field|  !field.default }
      .map { |field| TicketDecorator.display_name(field.name) }
  end

  def ticket_fields_condition
    if (custom_field_names + CustomFilterConstants::CONDITIONAL_FIELDS).exclude?(condition)
      errors[:condition] << :"is invalid"
    elsif CustomFilterConstants::FEATURES_KEYS_BY_FIELD.keys.include?(condition)
      unless TicketsFilter.accessible_filter?(condition, CustomFilterConstants::FEATURES_KEYS_BY_FIELD)
        errors[:condition] << :require_feature
        error_options.merge!(condition: { feature: CustomFilterConstants::FEATURES_NAMES_BY_FILED[condition],
            code: :access_denied })
      end
    end
  end

  def valid_params?
    @request_params.each do |key, value|
      errors[key] << :"is a invalid param" unless key.to_sym.in? CustomFilterConstants::QUERY_HASH_PARAMS
    end
  end

end
