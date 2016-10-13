class Va::RuleHandler
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
      evaluate_rule(evaluate_on.send(condition.dispatcher_key))
    end
  end
  
  def evaluate_rule(evaluate_on_value)
    #return evaluate_on_value.send(:casecmp, value)
    return false if condition.operator.nil?
    send(condition.operator, evaluate_on_value)
  end
  
  def filter_query
    send("filter_query_#{condition.operator}")
  end
end