class AccountAdminValidation < ApiValidation
  include AccountConstants

  attr_accessor :first_name, :last_name, :email, :phone, :invoice_emails

  validates_presence_of :first_name, :last_name, message: I18n.t('user.errors.required_field')

  validate :email_or_invoice_email_present?

  validates :email, format: { with: EMAIL_VALIDATOR, message: I18n.t('activerecord.errors.messages.email_invalid') },
                    if: -> { email.present? }

  validates :invoice_emails, data_type: {
    rules: Array, allow_nil: true
  },
                             custom_length: { maximum: MAX_INVOICE_EMAILS, message_options: { element_type: :values } },
                             array: {
                               data_type: {
                                 rules: String
                               },
                               custom_format: { with: EMAIL_VALIDATOR, message: I18n.t('activerecord.errors.messages.email_invalid') }
                             }, if: -> { invoice_emails.present? }

  def initialize(request_params, item = nil, allow_string_param = false)
    super(request_params, item, allow_string_param)
  end

  def email_or_invoice_email_present?
    errors[:email] << :missing_field if email.blank? && invoice_emails.blank?
  end
end
