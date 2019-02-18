class Proactive::EmailValidation < ::TicketValidation
  validates :email_config_id, :subject, required: { message: :field_validation_for_email }, if: :simple_outreach_create?

  def simple_outreach_create?
    validation_context == :simple_outreach_create
  end
end
