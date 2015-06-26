class ApiGroupValidation < ApiValidation
  attr_accessor :name, :escalate_to, :unassigned_for, :auto_ticket_assign, :agents, :error_options
  validates :name, presence: true
  validates :escalate_to, numericality: true, allow_nil: true
  validates :unassigned_for, inclusion: { in: ApiConstants::UNASSIGNED_FOR_MAP.keys, message: "can't be blank" }, allow_nil: true
  validates :auto_ticket_assign, inclusion: { in: [true, false], message: "can't be blank" }, allow_nil: true
  validates :agents, data_type: { rules: Array, allow_nil: true }, array: { numericality: { allow_nil: true } }
end
