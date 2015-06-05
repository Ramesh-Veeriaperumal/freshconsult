class TicketValidation < ApiValidation
  include ActiveModel::Validations

  attr_accessor :id, :cc_emails, :description, :description_html, :display_id, :due_by, :email_config_id, :fr_due_by, :group_id, :priority, :email,
                :phone, :twitter_id, :facebook_id, :requester_id, :name, :responder_id, :source, :status, :subject, :ticket_type,
                :product_id, :tags, :custom_fields, :account

  validates_with DateTimeValidator, fields: [:due_by, :fr_due_by], allow_nil: true
  validates :group_id, :requester_id, :responder_id, :display_id, :product_id, :email_config_id, numericality: { allow_nil: true }
  validates :requester_id, presence: true, if: :requester_id_mandatory?
  validates :name, presence: true, if: :name_required?
  validates :priority, inclusion: { in: TicketConstants::PRIORITY_TOKEN_BY_KEY.keys }, allow_nil: true
  validate :allowed_status? # Can't use inclusion validator as dynamic messages are not feasible
  validates :source, inclusion: { in: 1..TicketConstants::SOURCES.size }, allow_nil: true
  validates_with DataTypeValidator, rules: { 'Array' => ['tags', 'cc_emails'], 'Hash' => ['custom_fields'] }, allow_nil: true
  validates :email, format: { with: AccountConstants::EMAIL_REGEX, message: 'is not a valid email' }, if: :email_required?
  validates_each :cc_emails, &TicketsValidationHelper.email_validator # Expects a block
  validate :allowed_types? # Can't use inclusion validator as dynamic messages are not feasible
  # Should be part of bulk create API.
  # validates :closed_at, inclusion: { in: [nil], message: "invalid_field" }, :if => proc{|x| x.status != Helpdesk::TicketStatus.status_keys_by_name(Account.current)["Closed"] }
  # validates :resolved_at, inclusion: { in: [nil], message: "invalid_field" }, :if => proc{|x| x.status != Helpdesk::TicketStatus.status_keys_by_name(Account.current)["Resolved"] }

  def initialize(request_params, item, account)
    @account = account
    @cc_emails = item.cc_email[:cc_emails] if item
    @fr_due_by = item.try(:frDueBy) if item
    @custom_fields = item.try(:custom_field) if item
    super(request_params, item)
  end

  def requester_id_mandatory? # requester_id is must if any one of email/twitter_id/fb_profile_id/phone is not given.
    email.blank? && twitter_id.blank? && phone.blank? && facebook_id.blank?
  end

  def name_required? # Name mandatory if phone number of a non existent contact is given. so that the contact will get on ticket callbacks.
    id.blank? && email.blank? && twitter_id.blank? && facebook_id.blank? && phone.present? && requester_id.blank?
  end

  def email_required? # Email required if twitter_id/fb_profile_ids/phone/requester_id is blank.
    id.blank? && email.present? && twitter_id.blank? && facebook_id.blank? && phone.blank? && requester_id.blank?
  end

  def allowed_status? # Check if the status is present in the allowed list of enum values
    allowed_values = TicketsValidationHelper.ticket_status_values(@account)
    unless @status.blank? || allowed_values.include?(@status)
      errors.add(:status, "Should be a value in the list #{allowed_values.join(',')}")
    end
  end

  def allowed_types? # Check if the ticket type is present in the allowed list of enum values
    allowed_values = TicketsValidationHelper.ticket_type_values(@account)
    unless @ticket_type.blank? || allowed_values.include?(@ticket_type)
      errors.add(:ticket_type, "Should be a value in the list #{allowed_values.join(',')}")
    end
  end
end
