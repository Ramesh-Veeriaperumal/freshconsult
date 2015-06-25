class ApiGroupValidation < ApiValidation
  include ActiveModel::Validations
  attr_accessor :name, :escalate_to, :unassigned_for, :auto_ticket_assign, :agents, :error_options, :description
  validates :name, presence: true
  validates :escalate_to, numericality: true, allow_nil: true
  validates :unassigned_for, inclusion: { in: ApiConstants::UNASSIGNED_FOR_MAP.keys }, allow_nil: true
  validates :auto_ticket_assign, inclusion: { in: ApiConstants::BOOLEAN_VALUES }, allow_blank: true
  validates_with DataTypeValidator, rules: { Array => %w(agents) }, allow_nil: true
  validates_with DataTypeValidator, rules: { String => %w(name description) }
  validates_each :agents, &ApiGroupsValidationHelper.agents_validator
end
