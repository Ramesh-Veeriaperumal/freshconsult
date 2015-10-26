class ApiGroupValidation < ApiValidation
  attr_accessor :name, :escalate_to, :unassigned_for, :auto_ticket_assign, :agent_ids, :error_options, :description
  validates :name, required: true, length: { maximum: ApiConstants::MAX_LENGTH_STRING, message: :too_long }
  validates :escalate_to, custom_numericality: { allow_nil: true }
  validates :unassigned_for, custom_inclusion: { in: GroupConstants::UNASSIGNED_FOR_ACCEPTED_VALUES }, allow_nil: true
  validates :auto_ticket_assign, data_type: { rules: 'Boolean', allow_nil: true }
  validates :agent_ids, data_type: { rules: Array, allow_nil: true  }, array: { custom_numericality: { allow_nil: true, message: 'invalid_integer' } }
  validates :name, :description, data_type: { rules: String, allow_nil: true }

  def attributes_to_be_stripped
    GroupConstants::FIELDS_TO_BE_STRIPPED
  end
end
