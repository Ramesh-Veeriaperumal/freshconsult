class IntegratedUserValidation < FilterValidation
	

 attr_accessor :installed_application_id, :user_id

  validates :installed_application_id, required: { allow_nil: false, message: :installed_application_id_required }, custom_numericality: { only_integer: true, ignore_string: :allow_string_param }
  validates :user_id, required: { allow_nil: false, message: :user_id_required }, custom_numericality: { only_integer: true, ignore_string: :allow_string_param }
end