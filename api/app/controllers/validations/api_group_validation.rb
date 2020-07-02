class ApiGroupValidation < ApiValidation
  attr_accessor :name, :escalate_to, :unassigned_for, :auto_ticket_assign, :agent_ids, :error_options, :description, :group_type, :allow_agents_to_change_availability
  validates :name, data_type: { rules: String, required: true }
  validates :name, custom_length: { maximum: ApiConstants::MAX_LENGTH_STRING }
  validates :escalate_to, custom_numericality: { only_integer: true, greater_than: 0, allow_nil: true }
  validates :unassigned_for, custom_inclusion: { in: GroupConstants::UNASSIGNED_FOR_ACCEPTED_VALUES }, allow_nil: true
  validates :auto_ticket_assign, data_type: { rules: 'Boolean' }
  validates :agent_ids, data_type: { rules: Array }, array: { custom_numericality: { only_integer: true, greater_than: 0, allow_nil: true } }
  validates :description, data_type: { rules: String, allow_nil: true }
  validates :allow_agents_to_change_availability, data_type: { rules: 'Boolean' }
  validates :group_type, custom_inclusion: { in: proc { |x| x.account_group_types} , data_type: { rules: String } }, on: :create

  def attributes_to_be_stripped
    GroupConstants::ATTRIBUTES_TO_BE_STRIPPED
  end

  def account_group_types
    Account.current.group_types_from_cache.map(&:name)
  end
end
