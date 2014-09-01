class VA::Tester::Action < VA::Tester

  def fetch_random_unique_choice option
    sub_rule = test_variable[option]
    random_choice = sub_rule['choices'].reject{|choice| ['', '--', 0, -2].include? choice[0]}.sample
    random_choice_value = random_choice[0]
  end

  def check_working va_rule, ticket, option_name, option_hash
    unless exception?(option_hash)
      rule_value = option_hash[:feed_data][:value]
      send_keys  = option_hash[:check_against] || [option_name]
      value_in_ticket = send_keys.inject(ticket){ |object, send_key| object.send(send_key) }
      unless value_in_ticket == rule_value
        raise "value_in_ticket #{value_in_ticket} should be_eql to rule_value #{rule_value}"
      end
    else # EXCEPTIONS
      send(:"check_#{option_name}", ticket, option_name, option_hash)
    end
  end

  def scoper
    Account.current.observer_rules #password of trigger_webhook will be encrypted only for observer_rules
  end

  def rule_data option_name, value_hash
    { :action_data => [{:name => option_name}.merge(value_hash)] }
  end

  def execute_va_rule va_rule, ticket
    va_rule.trigger_actions(ticket)
  end

  private

    def check_send_email_to_group ticket, option_name, option_hash
      check_mail
    end

    def check_send_email_to_agent ticket, option_name, option_hash
      check_mail
    end

    def check_send_email_to_requester ticket, option_name, option_hash
      check_mail
    end

    def check_skip_notification ticket, option_name, option_hash
      raise "Skip Notification should be set to true" unless ticket.skip_notification == true
    end

    def check_trigger_webhook ticket, option_name, option_hash
      decrypt_and_check_password option_hash
      check_resque
    end

    def check_add_comment ticket, option_name, option_hash
      comment = ticket.notes.last
      body    = option_hash[:feed_data][:comment]
      body_in_note = comment.body
      raise "body_in_note #{body_in_note} should be equal to body #{body}" unless body_in_note == body

      creator_id = User.current.id
      creator_id_in_note = comment.user_id
      unless creator_id_in_note == creator_id
        raise "creator_id_in_note#{creator_id_in_note} should be_eql creator_id #{creator_id}"
      end

      raise "Comment should be private #{comment}" unless comment.private == true
    end

    def check_mail
      # Dunno how to check asda
    end

    def check_resque
      redis = Redis.new
      count = redis.llen("resque:queue:throttler_worker")
      raise "count #{count} should be_eql 1" unless count == 1
    end

    def decrypt_and_check_password option_hash
      webhook_action = Account.current.observer_rules.last.actions.select{ |action| 
                              action.action_key == 'trigger_webhook' }.first
      decrypted_password = webhook_action.send(:decrypt, webhook_action.act_hash[:password])
      unless decrypted_password.should == option_hash[:feed_data][:password]
        raise "Password #{webhook_action.act_hash[:password]} should be encrypted"
      end
    end

end