class IntegratedResourceValidation < FilterValidation

 attr_accessor :installed_application_id, :local_integratable_id,:local_integratable_type

  validates :installed_application_id, required: { allow_nil: false, message: :installed_application_id_required }, custom_numericality: { only_integer: true, ignore_string: :allow_string_param }
  validates :local_integratable_id, required: { allow_nil: false, message: :local_integratable_id_required }, custom_numericality: { only_integer: true, ignore_string: :allow_string_param }
  validates :local_integratable_type, data_type: { rules: String, allow_nil: true }

end