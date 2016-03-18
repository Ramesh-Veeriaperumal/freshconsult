class ConversationDelegator < BaseDelegator
  validate :validate_agent_emails, if: -> { note? && attr_changed?('to_emails', schema_less_note) && to_emails.present? }

  def validate_agent_emails
    invalid_emails = to_emails - Account.current.agents_from_cache.map { |x| x.user.email }
    unless invalid_emails.empty?
      errors[:notify_emails] << :invalid_agent_emails
      (self.error_options ||= {}).merge!(notify_emails: { invalid_emails: "#{invalid_emails.join(', ')}" })
    end
  end
end
