class Va::RuleHandler
  include Va::Constants

  attr_accessor :condition, :rule_hash, :value_key
  
  def initialize(condition, rule_hash)
    @condition, @rule_hash = condition, rule_hash
  end

  def value
    @value_key||= :value
    rule_hash[value_key]
  end

  def rule_type
    rule_hash[:rule_type]
  end

  def nested_rules
    rule_hash[:nested_rules]
  end

  def sub_value
    rule_hash[:business_hours_id]
  end

  def event_matches? check_value, check_var
    return true if has_any_value?(rule_hash[check_var])
    return false if has_any_field_excluding_none_value_without_lp_feature? rule_hash[check_var]
    return check_value.present? if has_any_value_excluding_none?(rule_hash[check_var])
    return false if rule_hash[check_var].nil?
    @value_key = check_var
    (is check_value)
  end

  def matches(evaluate_on)
    if evaluate_on.respond_to?(condition.dispatcher_key)
      lazy_evaluations = LAZY_EVALUATIONS[evaluate_on.class.name] || []
      actual_val = nil
      matched = if lazy_evaluations.include?(condition.dispatcher_key.to_sym)
                  evaluate_rule(nil) { |args = []| evaluate_on.safe_send(condition.dispatcher_key, *args) }
                else
                  actual_val = evaluate_on.safe_send(condition.dispatcher_key)
                  evaluate_rule(actual_val)
                end
      matched
    end
  end
  
  def evaluate_rule(evaluate_on_value, &block)
    #return evaluate_on_value.safe_send(:casecmp, value)
    #making sure that condition.operator is not tampered, to prevent remote code execution security issue
    return false if condition.operator.nil? || va_operator_list[condition.operator.to_sym].nil?
    safe_send(condition.operator, evaluate_on_value, &block)
  end
  
  def filter_query
    begin
      # checking whether the field is present in db or not and also whether the field has the called method
      condition.db_column && safe_send("filter_query_#{condition.operator}")
    rescue => e
      message = "Either field is not present or type of field is changed."
      Va::Logger::Automation.log_error(message, e, rule_hash)
      ["false"]
    end
  end

  def null_query(value = :null)
    column_name = condition.db_column
    value == :null ? NULL_QUERY % {db_column:column_name} : NOT_NULL_QUERY % {db_column:column_name}
  end

  def has_any_field_excluding_none_value_without_lp_feature?(value)
    has_any_value_excluding_none?(value) && !Account.current.va_any_field_without_none_enabled?
  end

  def has_any_value?(value)
    ANY_VALUE[:with_none] == value
  end

  def has_any_value_excluding_none?(value)
    ANY_VALUE[:without_none] == value
  end

end
