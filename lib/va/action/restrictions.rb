module Va::Action::Restrictions

  #Its a action -> action_restriction_method mapping.
  #Add the restriction_method name as a value and create a method for it.
  RESTRICTIONS_BY_ACTION_NAME = 
  {
    "send_email_to_group" => 
      { :method => "account_unverified?", 
        :error_msg_key => "admin.va_rules.errors.account_not_activated" },
    "send_email_to_agent" =>  
      { :method => "account_unverified?",
        :error_msg_key => "admin.va_rules.errors.account_not_activated" },
    "send_email_to_requester" =>  
      { :method => "account_unverified?",
        :error_msg_key => "admin.va_rules.errors.account_not_activated" },
  }

  def restricted?
    current_restriction = RESTRICTIONS_BY_ACTION_NAME[action_key]
    if current_restriction && send(current_restriction[:method])
      va_rule.errors.add(:base,I18n.t(current_restriction[:error_msg_key]))
    end
  end

  private
    def account_unverified?
      !Account.current.verified?
    end
end