class FieldServiceManagementValidation < ApiValidation
  attr_accessor :field_agents_can_manage_appointments, :geo_location_enabled, :location_tagging_enabled

  validates :field_agents_can_manage_appointments, :geo_location_enabled, :location_tagging_enabled, data_type: { rules: 'Boolean', allow_nil: false }
end
