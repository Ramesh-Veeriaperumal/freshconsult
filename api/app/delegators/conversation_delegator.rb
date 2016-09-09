class ConversationDelegator < BaseDelegator

  attr_accessor :email_config_id

  validate :validate_agent_emails, if: -> { note? && to_emails.present? && attr_changed?('to_emails', schema_less_note)}

  validate :validate_from_email, if: -> { email_conversation? && from_email.present? && attr_changed?('from_email', schema_less_note)}

  def initialize(record, options = {})
    super(record, options)
  end

  def validate_agent_emails
    invalid_emails = to_emails - Account.current.agents_from_cache.map { |x| x.user.email }
    unless invalid_emails.empty?
      errors[:notify_emails] << :invalid_agent_emails
      (self.error_options ||= {}).merge!(notify_emails: { invalid_emails: "#{invalid_emails.join(', ')}" })
    end
  end

  def validate_from_email
  	email_config = Account.current.email_configs.where(reply_email: from_email).first
    if email_config
      self.email_config_id = email_config.id
    else
      errors[:from_email] << :"can't be blank"
    end
  end
end
