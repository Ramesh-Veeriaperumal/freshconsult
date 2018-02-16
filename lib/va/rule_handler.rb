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
    return true if rule_hash[check_var]=="--"
    return false if rule_hash[check_var].nil?
    @value_key = check_var
    return(is check_value)
  end

  def matches(evaluate_on)
    if evaluate_on.respond_to?(condition.dispatcher_key)
      actual_val = evaluate_on.send(condition.dispatcher_key)
      matched = evaluate_rule(actual_val)
      Va::Logger::Automation.log "k=#{condition.dispatcher_key}::v=#{value}::o=#{condition.operator}::actual_val=#{actual_val}" unless matched
      matched
    end
  end
  
  def evaluate_rule(evaluate_on_value)
    #return evaluate_on_value.send(:casecmp, value)
    #making sure that condition.operator is not tampered, to prevent remote code execution security issue
    return false if condition.operator.nil? || va_operator_list[condition.operator.to_sym].nil?
    send(condition.operator, evaluate_on_value)
  end
  
  def filter_query
    send("filter_query_#{condition.operator}")
  end
end