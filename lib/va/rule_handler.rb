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

  def matches(evaluate_on)
    if evaluate_on.respond_to?(condition.key)
      evaluate_rule(evaluate_on.send(condition.key))
    end
  end
  
  def evaluate_rule(evaluate_on_value)
    #return evaluate_on_value.send(:casecmp, value)   
    send(condition.operator, evaluate_on_value)
  end
  
  def filter_query
    send("filter_query_#{condition.operator}")
  end
end
