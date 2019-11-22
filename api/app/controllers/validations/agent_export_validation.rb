class AgentExportValidation < ApiValidation
  attr_accessor :response_type, :fields
  validates :response_type, custom_inclusion: { in: AgentConstants::RECEIVE_VIA, detect_type: true }, required: true, on: :export
  validates :fields, required: true, data_type: { rules: Array, allow_blank: false }, on: :export
  validate :check_of_invalid_fields, on: :export, if: -> { errors[:fields].blank? }
  validate :check_uniquess_for_fields, on: :export, if: -> { errors[:fields].blank? }, on: :export

  def check_of_invalid_fields
    valid_fields = Account.current.skill_based_round_robin_enabled? ? AgentConstants::AGENT_EXPORT_FIELDS_WITH_SKILLS : AgentConstants::AGENT_EXPORT_FIELDS_WITHOUT_SKILLS
    invalid_fields = @fields - valid_fields
    if invalid_fields.present?
      errors[:fields] = :invalid_values
      error_options[:fields] = { fields: invalid_fields.join(',').to_s }
    end
  end

  def check_uniquess_for_fields
    duplicate_fields = @fields.select { |field| @fields.count(field) > 1 }.uniq
    if duplicate_fields.present?
      errors[:fields] = :duplicate_not_allowed
      error_options[:fields] = { name: 'fields', list: duplicate_fields.join(', ').to_s }
    end
  end
end
