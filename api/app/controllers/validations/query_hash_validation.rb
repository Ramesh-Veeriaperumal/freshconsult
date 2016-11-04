class QueryHashValidation < FilterValidation
  
  attr_accessor :condition, :operator, :value, :type

  validates :condition, required: true, data_type: { rules: String }
  validates :operator, required: true, data_type: { rules: String }, custom_inclusion: { in: CustomFilterConstants::OPERATORS }
  validates :type, required: true, data_type: { rules: String }, custom_inclusion: { in: CustomFilterConstants::QUERY_TYPE_OPTIONS }
  validates :value, required: true

  validates :value, data_type: { rules: Array }, if: -> { CustomFilterConstants::ARRAY_VALUED_OPERATORS.include?(operator) }

  validate :ticket_fields_condition

  def custom_field_names
    @custom_field_names ||= Account.current.ticket_fields_from_cache
      .select { |field|  !field.default }
      .map { |field| TicketDecorator.display_name(field.name) }
  end

  def ticket_fields_condition
    unless (custom_field_names + CustomFilterConstants::CONDITIONAL_FIELDS).include?(condition)
      errors[:condition] << :"is invalid"
    end
  end

end
