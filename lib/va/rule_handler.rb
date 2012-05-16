class Va::RuleHandler
  attr_accessor :condition, :rule_hash
  
  def initialize(condition, rule_hash)
    @condition, @rule_hash = condition, rule_hash
  end
  
  def value
    rule_hash[:value]
  end
  
  def rule_type
    rule_hash[:rule_type]
  end

  def nested_rules
    rule_hash[:nested_rules]
  end

  def match_nested_rules(evaluate_on)
    to_ret = false
    if evaluate_on.respond_to?(condition.key)
      #return evaluate_on.send(filter.key).send(operator_fn(@operator), @values)
      to_ret = evaluate_rule(evaluate_on.send(condition.key))
      return to_ret unless to_ret
    end

    (nested_rules || []).each do |nested_rule|
      if evaluate_on.respond_to?(nested_rule[:name])
        to_ret = send(condition.operator, evaluate_on.send(nested_rule[:name]),nested_rule[:value])
        return to_ret unless to_ret
      else
        RAILS_DEFAULT_LOGGER.debug "############### The ticket did not respond to #{nested_rule[:name]} property"
      end
    end
    return to_ret
  end

  def matches(evaluate_on)
    if rule_type == "nested_rule"
      match_nested_rules(evaluate_on)  
    else
      if evaluate_on.respond_to?(condition.key)
        evaluate_rule(evaluate_on.send(condition.key))
      end
    end
  end
  
  def evaluate_rule(evaluate_on_value)
    #return evaluate_on_value.send(:casecmp, value)   
    send(condition.operator, evaluate_on_value)
  end
  
  def filter_query
    if rule_type == "nested_rule"
      query_conditions = send("filter_query_#{condition.operator}", condition.key, value)
      (nested_rules || []).each do |nested_rule|
        query_condition = send("filter_query_#{condition.operator}", nested_rule[:name], nested_rule[:value])
        query_conditions = "#{query_conditions} and #{query_condition}"
      end
      ["(#{query_conditions})"]
    else
      send("filter_query_#{condition.operator}")
    end
  end
end
