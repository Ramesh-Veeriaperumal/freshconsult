class Va::Handlers::NestedField < Va::RuleHandler

  def match_nested_rules(evaluate_on)
    to_ret = false
    if evaluate_on.respond_to?(condition.key)
      #return evaluate_on.send(filter.key).send(operator_fn(@operator), @values)
      to_ret = send(condition.operator, evaluate_on.send(condition.key), value)
      return to_ret unless to_ret
      
      (nested_rules || []).each do |nested_rule|
        if evaluate_on.respond_to?(nested_rule[:name])
          to_ret = send(condition.operator, evaluate_on.send(nested_rule[:name]),nested_rule[:value])
          return to_ret unless to_ret
        else
          RAILS_DEFAULT_LOGGER.debug "############### The ticket did not respond to #{nested_rule[:name]} property"
        end
      end
    end
    
    return to_ret
  end

  def matches(evaluate_on)
    match_nested_rules(evaluate_on)  
  end

  def filter_query
    query_conditions = send("filter_query_#{condition.operator}", condition.key, value)
    (nested_rules || []).each do |nested_rule|
      query_condition = send("filter_query_#{condition.operator}", nested_rule[:name], nested_rule[:value])
      query_conditions = "#{query_conditions} and #{query_condition}"
    end
    ["(#{query_conditions})"]
  end

  private
    def is(evaluate_on_value, field_value)
      evaluate_on_value && evaluate_on_value.casecmp(field_value.to_s) == 0
    end

    def is_not(evaluate_on_value, field_value)
      !is(evaluate_on_value, field_value)
    end
   
    def filter_query_is(field_key,field_value)
      "flexifields.#{FlexifieldDefEntry.ticket_db_column field_key} = '#{field_value.to_s}'"
    end
    
    def filter_query_is_not(field_key,field_values)
      "flexifields.#{FlexifieldDefEntry.ticket_db_column field_key} != '#{field_value.to_s}'"
    end
end
