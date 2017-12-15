class IntegratedUserValidation < FilterValidation
  attr_accessor :installed_application_id, :user_id, :username, :password

  validates :username, required: { allow_nil: false, message: :username_required }, data_type: { rules: String }, if: -> { @action.to_sym == :user_credentials_add }
  validates :password, required: { allow_nil: false, message: :password_required }, data_type: { rules: String }, if: -> { @action.to_sym == :user_credentials_add }

  validates :installed_application_id, required: { allow_nil: false, message: :installed_application_id_required }, custom_numericality: { only_integer: true, ignore_string: :allow_string_param }
  validates :user_id, required: { allow_nil: false, message: :user_id_required }, custom_numericality: { only_integer: true, ignore_string: :allow_string_param }, if: -> { @action.to_sym == :index }

  def initialize(request_params, item, allow_string_param = false)
    super(request_params, item, allow_string_param)
    @action = request_params[:action]
  end
end