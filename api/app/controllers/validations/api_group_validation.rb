class ApiGroupValidation < ApiValidation
  attr_accessor :name, :escalate_to, :unassigned_for, :auto_ticket_assign, :agent_ids, :error_options, :description
  validates :name, required: true, custom_length: { maximum: ApiConstants::MAX_LENGTH_STRING, message: :too_long }
  validates :escalate_to, numericality: true, allow_nil: true
  validates :unassigned_for, custom_inclusion: { in: GroupConstants::UNASSIGNED_FOR_MAP.keys }, allow_nil: true
  validates :auto_ticket_assign, custom_inclusion: { in: ApiConstants::BOOLEAN_VALUES }, allow_nil: true
  validates :agent_ids, data_type: { rules: Array, allow_nil: true }, array: { numericality: { allow_nil: true } }
  validates :name, :description, data_type: { rules: String, allow_nil: true }
end
