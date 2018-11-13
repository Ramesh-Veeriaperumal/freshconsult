class AccountAdminValidation < ApiValidation
  include AccountConstants

  attr_accessor :first_name, :last_name, :email, :phone

  validates_presence_of :email, :first_name, :last_name, :message => I18n.t('user.errors.required_field')
  validates :email, format: { with: EMAIL_VALIDATOR, message: I18n.t('activerecord.errors.messages.email_invalid') },
                    if: -> { email.present? }

  def initialize(request_params, item = nil, allow_string_param = false)
    super(request_params, item, allow_string_param)
  end
end
