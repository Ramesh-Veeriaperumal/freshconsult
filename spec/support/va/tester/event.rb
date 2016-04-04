class VA::Tester::Event < VA::Tester

  def fetch_random_unique_choice option
    sub_rule = test_variable[option]
    choices  = sub_rule['choices']
    choices.reject!{|choice| ['', '--', 0].include? choice[0]}
    random_choice = choices.delete(choices.sample)
    random_choice_value = random_choice[0]
  end

  def check_working va_rule, ticket, option_name, option_hash
    unless exception?(option_hash)
      feed_data = option_hash[:feed_data]
      from = feed_data[:from] || feed_data[:value]
      to = feed_data[:to]
      current_events_generated = fetch_events(ticket, option_name, from, to)
      result = (current_events_generated[option_name] == get_change(feed_data))
      unless va_rule.event_matches?(current_events_generated, ticket) == result
        raise "event_matches of #{va_rule} should be_eql to true"
      end
    else # EXCEPTIONS
      send(:"check_#{option_name}", va_rule, ticket, option_name, option_hash)
    end
  end

  def scoper
    Account.current.observer_rules
  end

  def rule_data option_name, value_hash
    { :filter_data => DEFAULT_FILTER_DATA.merge(:events => [{:name => option_name}.merge(value_hash)]) }
  end

  private

    def get_change feed_data
      case feed_data.keys.count
      when 2 then [feed_data[:from], feed_data[:to]]
      when 1 then feed_data[:value].respond_to?(:to_sym) ? feed_data[:value].to_sym : feed_data[:value]
      when 0 then []
      end
    end

    def check_ticket_action va_rule, ticket, option_name, option_hash
      feed_data = option_hash[:feed_data]
      current_events = { option_name => get_change(feed_data) }
      unless va_rule.event_matches?(current_events, ticket) == true
        raise "event_matches of #{va_rule} should be_eql to true"
      end
    end

    def fetch_events ticket, option_name, from, to
      object = fetch_object ticket, option_name
      attribute_to_change = fetch_attribute option_name
      events_method = fetch_events_method object
      unless attribute_to_change.nil?
        object.update_attributes(attribute_to_change => from)
        object.send("#{attribute_to_change}=", to)
      end
      object.send events_method
    end

    def fetch_object ticket, option_name
      case option_name
      when :note_type then ticket.notes.first
      when :reply_sent then ticket.notes.last
      when :time_sheet_action then ticket.time_sheets.first
      when :customer_feedback then ticket.survey_results.first
      else ticket
      end
    end

    def fetch_attribute option_name
      case option_name
      when :time_sheet_action then :time_spent
      when :note_type then nil
      when :reply_sent then nil
      when :customer_feedback then nil
      else option_name
      end
    end

    def fetch_events_method object
      case object
      when Helpdesk::Ticket then :update_ticket_related_changes
      else :update_observer_events
      end
    end

    
end