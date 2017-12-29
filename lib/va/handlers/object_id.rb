class Va::Handlers::ObjectId < Va::RuleHandler

  private

    def proper_value
      value.blank? ? nil : value.to_i
    end

    def numeric_values_list
      [*value].map(&:to_i)
    end

    def is(evaluate_on_value)
      evaluate_on_value == proper_value
    end

    def is_not(evaluate_on_value)
      !is(evaluate_on_value)
    end

    def in(evaluate_on_value)
      evaluate_on_value ||= 0
      numeric_values_list.include?(evaluate_on_value)
    end

    def not_in(evaluate_on_value)
      evaluate_on_value ||= 0
      ! numeric_values_list.include?(evaluate_on_value)
    end

    def filter_query_in
      construct_query QUERY_OPERATOR[:in], numeric_values_list, '(?)'
    end

    def filter_query_not_in
      construct_query QUERY_OPERATOR[:not_in], numeric_values_list, '(?)'
    end

    def filter_query_is
      construct_query (proper_value ? QUERY_OPERATOR[:equal] : QUERY_OPERATOR[:is])
    end

    def filter_query_is_not
      construct_query (proper_value ? QUERY_OPERATOR[:not_equal] : QUERY_OPERATOR[:is_not])
    end

    #Checking 'proper_value' to avoid "column != null" condition as its invalid
    def filter_query_negation
      [ " #{condition.db_column} #{proper_value ? '!=' : 'is not'} ? OR #{condition.db_column} IS NULL ", proper_value ]
    end
    
    def construct_query(q_operator, value = proper_value, replacement_operator = '?')
      is_none_condition = (q_operator == QUERY_OPERATOR[:in] and [*value].include?("")) ? "OR #{condition.db_column} IS NULL" : ""
      [ " ( #{condition.db_column} #{q_operator} #{replacement_operator} #{is_none_condition} ) ", value ]
    end

end