class ApiGroupValidation < ApiValidation
  attr_accessor :name, :escalate_to, :unassigned_for, :auto_ticket_assign, :user_ids, :error_options, :description
  validates :name, required: true
  validates :escalate_to, numericality: true, allow_nil: true
  validates :unassigned_for, custom_inclusion: { in: GroupConstants::UNASSIGNED_FOR_MAP.keys }, allow_nil: true
  validates :auto_ticket_assign, custom_inclusion: { in: ApiConstants::BOOLEAN_VALUES }, allow_nil: true
  validates :user_ids, data_type: { rules: Array, allow_nil: true }, array: { numericality: { allow_nil: true } }
  validates :name, :description, data_type: { rules: String, allow_nil: true }
end
