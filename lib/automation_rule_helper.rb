module AutomationRuleHelper
  include Va::Constants
  include Redis::AutomationRuleRedis

  def update_ticket_execute_count(rule_ids_with_count = {})
    return unless (Account.current.automation_rule_execution_count_enabled? && rule_ids_with_count.present?)
    set_expiry_of_account_rule(RULE_EXEC_COUNT_EXPIRY_DURATION)
    rule_ids_with_count.each_pair do |rule_id, count|
      inc_automation_rule_exec_count(rule_id, count)
    end
  end

  def get_rules_executed_count(rule_ids = [])
    current_time = Time.zone.now
    previous_days = RULE_EXEC_COUNT_EXPIRY_DURATION / (1.day.to_i)
    previous_days = 1 if previous_days == 0
    response = []
    (previous_days).times do |day|
      fetch_time = current_time - day.days
      month, day = fetch_time.month, fetch_time.day
      response << get_multi_automation_key_values(rule_ids, {month: month, day: day})
    end
    response
  end
end
