class ApiGroupValidation < ApiValidation
  attr_accessor :name, :escalate_to, :unassigned_for, :auto_ticket_assign, :agents, :error_options, :description
  validates :name, presence: true
  validates :escalate_to, numericality: true, allow_nil: true
  validates :unassigned_for, included: { in: ApiConstants::UNASSIGNED_FOR_MAP.keys }, allow_nil: true
  validates :auto_ticket_assign, included: { in: ApiConstants::BOOLEAN_VALUES }, allow_nil: true
  validates :agents, data_type: { rules: Array, allow_nil: true }, array: { numericality: { allow_nil: true } }
  validates data_type: { rules: { String => %w(name description) } }
end
