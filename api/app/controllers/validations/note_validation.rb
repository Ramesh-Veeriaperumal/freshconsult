class NoteValidation < ApiValidation
  include ActiveModel::Validations

  attr_accessor :body, :body_html, :private, :incoming, :user_id, :notify_emails, :ticket_id, :attachments

  validates :user_id, numericality: { allow_nil: true }
  validates :ticket_id, numericality: true
  validates :private, :incoming, inclusion: { in: ApiConstants::BOOLEAN_VALUES }, allow_blank: true
  validates_with DataTypeValidator, rules: { 'Array' => ['notify_emails', 'attachments'] }, allow_nil: true
  validates_each :notify_emails, &TicketsValidationHelper.email_validator
  validates_each :attachments, &TicketsValidationHelper.attachment_validator

  def initialize(request_params, item)
    @notify_emails = item.try(:to_emails)
    @ticket_id = item.try(:notable_id)
    super(request_params, item)
  end
end
