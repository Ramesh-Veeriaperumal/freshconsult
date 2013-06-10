class Va::Handlers::ObjectId < Va::RuleHandler

  private
    def proper_value
      value.blank? ? nil : value.to_i
    end
  
    def is(evaluate_on_value)
      evaluate_on_value == proper_value
    end

    def in(evaluate_on_value)
      value.map(&:to_i).include?(evaluate_on_value)
    end

    def filter_query_is
      construct_query (proper_value ? '=' : 'is')
    end

    def filter_query_negation
      [ " #{condition.db_column} != ? OR #{condition.db_column} IS NULL ", proper_value ]
    end
    
    def construct_query(q_operator)
      [ "#{condition.db_column} #{q_operator} ?", proper_value ]
    end

end