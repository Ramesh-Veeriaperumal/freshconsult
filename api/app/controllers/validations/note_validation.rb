class NoteValidation < ApiValidation
  include ActiveModel::Validations

  attr_accessor :body, :body_html, :private, :user_id, :incoming, :notify_emails, :ticket_id, :attachments, :cc_emails, :bcc_emails

  validates :user_id, numericality: { allow_nil: true }
  validates :ticket_id, numericality: true
  validates :private, :incoming, inclusion: { in: ApiConstants::BOOLEAN_VALUES }, allow_blank: true
  validates_with DataTypeValidator, rules: { Array => %w(notify_emails attachments cc_emails bcc_emails) }, allow_nil: true
  validates_each :notify_emails, :cc_emails, :bcc_emails, &TicketsValidationHelper.email_validator
  validates_each :attachments, &TicketsValidationHelper.attachment_validator

  def initialize(request_params, item)
    @notify_emails = item.try(:to_emails)
    @ticket_id = item.try(:notable_id)
    super(request_params, item)
  end
end
