module BusinessRulesObserver
  def fire_event(event_name)
    events = []
    if event_name == :update
      CHECK_FOR_UPDATE[self.class].each{|chk_prop|
        chk_prop = chk_prop.to_s
        prop_changed = self.send("#{chk_prop}_changed?")
        Rails.logger.debug "#{chk_prop} changed : #{prop_changed}"
        events.push("#{event_name}_#{chk_prop}".to_sym) if prop_changed
      }
    else
      events.push(event_name)
    end
    send_later(:biz_rules_check, events)
  end

  def biz_rules_check(events)
    evaluate_on = self
    begin
      RAILS_DEFAULT_LOGGER.debug("Invoked business rule check for #{events}")
      unless events.blank?
        evaluate_on.account.account_va_rules.observer_biz_rules.each do |vr|
          ret_evaluate_on = vr.pass_through(evaluate_on, events)
          evaluate_on = ret_evaluate_on unless ret_evaluate_on.blank?
        end
      end
    rescue Exception => e
      NewRelic::Agent.notice_error(e)
    end
  end

  CHECK_FOR_UPDATE = {Helpdesk::Ticket=>[:status]}
end

#INSERT INTO `delayed_jobs` (`attempts`, `last_error`, `failed_at`, `priority`, `handler`, `updated_at`, `run_at`, `locked_by`, `created_at`, `locked_at`) VALUES(0, NULL, NULL, 0, '--- !ruby/struct:Delayed::PerformableMethod \nobject: AR:Helpdesk::Ticket:63\nmethod: :biz_rules_check\nargs: \n- - :update_status\n\"@account\": AR:Account:1\n', '2012-08-02 06:44:43', '2012-08-02 06:44:43', NULL, '2012-08-02 06:44:43', NULL)
