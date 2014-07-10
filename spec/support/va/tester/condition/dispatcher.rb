class  VA::Tester::Condition::Dispatcher < VA::Tester::Condition

  include VA::OperatorHelper::Dispatcher

  def check_working va_rule, ticket, option_name, option_hash, operator, operator_type
    unless exception?(option_hash)
      rule_value = option_hash[:feed_data][:value]
      send_key   = option_name
      return_value = (compare ticket.send(send_key), rule_value, operator, option_name)
      unless va_rule.matches(ticket) == return_value
        raise "matches for va_rule #{va_rule} should be_eql return_value #{return_value}"
      end
    else # EXCEPTIONS
      send(:"check_#{option_name}", ticket, option_name, option_hash, operator)
    end
  end

  def scoper
    Account.current.va_rules
  end

  def rule_data option_name, value_hash, operator
    { :filter_data => [{:name => option_name, :operator => operator}.merge(value_hash)] }
  end

  private

    def compare ticket_value, rule_value, operator, option_name
      return send(:contains, ticket_value, rule_value) if option_name == :ticlet_cc && operator == 'is' #hack
      return send(:does_not_contain, ticket_value, rule_value) if option_name == :ticlet_cc && operator == 'is_not' #hack
      send(operator, ticket_value, rule_value)
    end

    def check_subject_or_description ticket, option_name, option_hash, operator
      rule_value = option_hash[:feed_data][:value]
      subject = ticket.subject
      description = ticket.description
      send(operator, subject, rule_value) || send(operator, description, rule_value)
    end

end