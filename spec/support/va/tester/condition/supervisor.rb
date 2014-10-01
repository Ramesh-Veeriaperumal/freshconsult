class VA::Tester::Condition::Supervisor < VA::Tester::Condition

  include VA::OperatorHelper::Dispatcher
  include VA::OperatorHelper::Supervisor

  def check_working va_rule, ticket, option_name, option_hash, operator, operator_type
    unless exception?(option_hash)
      rule_value = option_hash[:feed_data][:value]
      send_key   = va_rule.conditions.first.dispatcher_key
      ticket_value = ticket.send(send_key)
      should_pick = compare(ticket_value, rule_value, option_name, operator.to_sym, operator_type)

      filter_query = va_rule.filter_query
      negation_query = va_rule.negation_query
      joins  = va_rule.get_joins(["#{filter_query[0]} #{negation_query[0]}"])
      picked = fetched?(ticket, joins, filter_query, negation_query)

      unless should_pick == picked
        raise "Discrepancy between should_pick? #{should_pick} and picked? #{picked} for va_rule #{va_rule} and ticket #{ticket.inspect}"
      end
    else # EXCEPTIONS
      send(:"check_#{option_name}", ticket, option_name, option_hash, operator)
    end
  end

  def scoper
    Account.current.supervisor_rules
  end

  def rule_data option_name, value_hash, operator
    { :filter_data => [{:name => option_name.to_s, :operator => operator}.merge(value_hash)] }
  end

  private

    def fetched? ticket, joins, filter_query, negation_query
      fetched = Account.current.tickets.where(negation_query).where(filter_query).
                  updated_in(1.month.ago).visible.joins(joins).select("helpdesk_tickets.*").pluck(:id)
      fetched.include?(ticket.id)
    end

    def compare ticket_value, rule_value, option_name, operator, operator_type
      return false if ticket_value.nil?
      return send(operator, ticket_value, rule_value) if [:inbound_count, :outbound_count].include?(option_name)
      case operator_type
      when 'hours' then send("hours_since_#{operator}", ticket_value, rule_value)
      when 'email'
        operator = :contains if operator == :is
        operator = :does_not_contain if operator == :is_not
        send(operator, ticket_value, rule_value)
      else
        send(operator, ticket_value, rule_value)
      end
    end

end