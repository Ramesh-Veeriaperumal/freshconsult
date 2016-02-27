class ApiGroupValidation < ApiValidation
  attr_accessor :name, :escalate_to, :unassigned_for, :auto_ticket_assign, :agent_ids, :error_options, :description
  validates :name, data_type: { rules: String, required: true }
  validates :name, length: { maximum: ApiConstants::MAX_LENGTH_STRING, message: :too_long }, if: -> { errors[:name].blank? }
  validates :escalate_to, custom_numericality: { only_integer: true, greater_than: 0, allow_nil: true }
  validates :unassigned_for, custom_inclusion: { in: GroupConstants::UNASSIGNED_FOR_ACCEPTED_VALUES }, allow_nil: true
  validates :auto_ticket_assign, data_type: { rules: 'Boolean', allow_unset: true }
  validates :agent_ids, data_type: { rules: Array, allow_unset: true }, array: { custom_numericality: { only_integer: true, greater_than: 0, allow_nil: true, custom_message: :invalid_integer } }
  validates :description, data_type: { rules: String, allow_nil: true }

  def attributes_to_be_stripped
    GroupConstants::ATTRIBUTES_TO_BE_STRIPPED
  end
end
