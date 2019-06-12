class TicketFieldValidation < ApiValidation
  attr_accessor :id, :label_for_customers, :label, :description, :position, :type, :level,
                :required_for_closure, :required_for_agents, :required_for_customers, :customers_can_edit,
                :displayed_to_customers

  validates :label, :type, data_type: { rules: String, allow_nil: false, required: true }, custom_length: { maximum: ApiConstants::MAX_LENGTH_STRING }

  validates :label_for_customers, data_type: { rules: String }, custom_length: { maximum: ApiConstants::MAX_LENGTH_STRING }

  validates :type, custom_inclusion: { in: Helpdesk::TicketField::MODIFIABLE_CUSTOM_FIELD_TYPES }, if: :create?

  # validates :type, custom_inclusion: { in: ApiTicketConstants::FIELD_TYPES }, if: :update?

  validates :description, data_type: { rules: String }, custom_length: { maximum: ApiConstants::MAX_LENGTH_STRING }

  validates :required_for_closure, :required_for_agents, :required_for_customers,
            :customers_can_edit, :displayed_to_customers, data_type: { rules: 'Boolean' }

  validates :position, custom_numericality: { only_integer: true, greater_than: 0, allow_nil: false }

  validates :level, custom_numericality: { only_integer: true, greater_than: 1, allow_nil: false }, if: :level_2_or_3?

  def level_2_or_3?
    type == TicketFieldsConstants::NESTED_FIELD && level.present?
  end
end
