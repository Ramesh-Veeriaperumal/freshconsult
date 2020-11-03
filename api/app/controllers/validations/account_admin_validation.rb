class AccountAdminValidation < ApiValidation
  include AccountConstants

  attr_accessor :first_name, :last_name, :email, :phone, :invoice_emails, :skip_mandatory_checks, :feedback_widget, :company_name

  validates_presence_of :first_name, :last_name, message: I18n.t('user.errors.required_field'), unless: -> { skip_mandatory_checks_request? }

  validate :email_or_invoice_email_present?, unless: -> { skip_mandatory_checks_request? }

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

  validates :skip_mandatory_checks, data_type: { rules: 'Boolean' }, on: :preferences=

  validates :feedback_widget, data_type: { rules: Hash }, hash: { validatable_fields_hash: proc { |x| x.feedback_widget_format } }, allow_nil: true, on: :preferences=

  def initialize(request_params, item = nil, allow_string_param = false)
    super(request_params, item, allow_string_param)
  end

  def email_or_invoice_email_present?
    errors[:email] << :missing_field if email.blank? && invoice_emails.blank?
  end

  def feedback_widget_format
    {
      disable_captcha: {
        data_type: {
          rules: 'Boolean'
        }
      }
    }
  end

  private

    def skip_mandatory_checks_request?
      validation_context == :preferences=
    end
end
