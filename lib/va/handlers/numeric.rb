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

    def greater_than(evaluate_on_value)
      evaluate_on_value > numeric_value
    end

    def less_than(evaluate_on_value)
      evaluate_on_value < numeric_value
    end

    def in(evaluate_on_value)
      value.map(&:to_i).include?(evaluate_on_value)
    end
    
    def filter_query_is
      construct_query '='
    end
    
    def filter_query_is_not
      construct_query '!='
    end
    
    def filter_query_greater_than
      construct_query '>'
    end
    
    def filter_query_less_than
      construct_query '<'
    end
    
    def construct_query(q_operator)
      [ "#{condition.db_column} #{q_operator} ?", numeric_value ]
    end

    def filter_query_negation
      [ "#{condition.db_column} IS NULL OR #{condition.db_column} != ?", numeric_value ]
    end
end