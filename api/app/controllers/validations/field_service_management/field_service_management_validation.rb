class FieldServiceManagementValidation < ApiValidation
  attr_accessor :field_agents_can_manage_appointments

  validates :field_agents_can_manage_appointments, data_type: { rules: 'Boolean', allow_nil: false }
end
