class IntegratedResourceValidation < ApiValidation
  attr_accessor :remote_integratable_type, :local_integratable_id, :installed_application_id

  validates :remote_integratable_type, data_type: { rules: String, allow_nil: true }
  validates :local_integratable_id, required: { allow_nil: false, message: :local_integratable_id_required }, custom_numericality: { only_integer: true, greater_than: 0, ignore_string: :allow_string_param }
  validates :installed_application_id, required: { allow_nil: false, message: :installed_application_id_required }, custom_numericality: { only_integer: true, ignore_string: :allow_string_param }
end
