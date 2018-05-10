class Va::Handlers::NestedField < Va::RuleHandler

  def match_nested_rules(evaluate_on)
    to_ret = false
    #making sure that condition.operator is not tampered, to prevent remote code execution security issue
    return to_ret if condition.operator.nil? || va_operator_list[condition.operator.to_sym].nil?
    if evaluate_on.respond_to?(condition.key)
      #return evaluate_on.safe_send(filter.key).safe_send(operator_fn(@operator), @values)
      evaluate_on_value = evaluate_on.safe_send(condition.key)
      to_ret = safe_send(condition.operator, evaluate_on_value, value)
      return true if has_any_value? value
      return false if has_any_field_excluding_none_value_without_lp_feature? value
      return evaluate_on_value.present? if has_any_value_excluding_none? value
      return to_ret unless to_ret
      
      (nested_rules || []).each do |nested_rule|
        return true if has_any_value? nested_rule[:value]
        if evaluate_on.respond_to?(nested_rule[:name])
          evaluate_on_nested_value = evaluate_on.safe_send(nested_rule[:name])
          return false if has_any_field_excluding_none_value_without_lp_feature? nested_rule[:value]
          return evaluate_on_nested_value.present? if has_any_value_excluding_none? nested_rule[:value]
          to_ret = safe_send(condition.operator, evaluate_on_nested_value, nested_rule[:value])
          return to_ret unless to_ret
        else
          Rails.logger.debug "############### The ticket did not respond to #{nested_rule[:name]} property"
        end
      end
    end
    
    return to_ret
  end

  def matches(evaluate_on)
    match_nested_rules(evaluate_on)  
  end

  def filter_query
    return ["(False)"] if has_any_field_excluding_none_value_without_lp_feature? value
    any_value_query = has_any_value_excluding_none?(value) ? ["(#{not_null_query(condition.key)[0]})", nil] : ''
    return any_value_query if has_any_value?(value) || has_any_value_excluding_none?(value)

    query_conditions, values = safe_send("filter_query_#{condition.operator}", condition.key, (query_value value))
    values = [values]
    (nested_rules || []).each do |nested_rule|
      return ["(False)"] if has_any_field_excluding_none_value_without_lp_feature? nested_rule[:value]
      any_value_query = (has_any_value_excluding_none?(nested_rule[:value]) ? " and #{not_null_query(nested_rule[:name])[0]}" : '')
      return ["(#{query_conditions}#{any_value_query})"].push(*(values << nil)) if has_any_value?(nested_rule[:value]) || has_any_value_excluding_none?(nested_rule[:value])
      each_query_condition, each_value = safe_send("filter_query_#{condition.operator}", nested_rule[:name], (query_value nested_rule[:value]))
      query_conditions = "#{query_conditions} and #{each_query_condition}"
      values << each_value
    end
    ["(#{query_conditions})"].push(*values)
  end

  def not_null_query(field_key)
    filter_query_is_not field_key, nil
  end

  private

    def query_value value
      value.empty? ? nil : "#{value}"
    end

    def is(evaluate_on_value, field_value)
      evaluate_on_value.to_s.casecmp(field_value.to_s) == 0
    end

    def is_not(evaluate_on_value, field_value)
      !is(evaluate_on_value, field_value)
    end
   
    def filter_query_is(field_key,field_value)
      construct_query (field_value.nil? ? QUERY_OPERATOR[:is] : QUERY_OPERATOR[:equal]), field_key, field_value
    end
    
    def filter_query_is_not(field_key,field_value)
      construct_query (field_value.nil? ? QUERY_OPERATOR[:is_not] : QUERY_OPERATOR[:not_equal]), field_key, field_value
    end

    def construct_query query_operator, field_key, field_value
      ["flexifields.#{FlexifieldDefEntry.ticket_db_column field_key} #{query_operator} ?", field_value]
    end

    def filter_query_negation(field_key,field_value)
      ["flexifields.#{FlexifieldDefEntry.ticket_db_column field_key} IS NULL OR flexifields.#{FlexifieldDefEntry.ticket_db_column field_key} != ?", field_value]
    end
end
