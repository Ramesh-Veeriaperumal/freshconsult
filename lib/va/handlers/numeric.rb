class Va::Handlers::Numeric < Va::RuleHandler

  private
    def numeric_value
      value.to_i
    end
  
    def is(evaluate_on_value)
      evaluate_on_value == numeric_value
    end

    def is_not(evaluate_on_value)
      !is(evaluate_on_value)
    end
    
    def filter_query_is
      [ "#{condition.db_column} = ?", numeric_value ]
    end
    
    def filter_query_is_not
      [ "#{condition.db_column} != ?", numeric_value ]
    end

end