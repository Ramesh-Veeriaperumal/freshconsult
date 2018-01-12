class Va::Handlers::ObjectId < Va::RuleHandler

  private
    NULL_QUERY = "OR %{db_column} IS NULL"
    NOT_NULL_QUERY = "OR %{db_column} IS NOT NULL"

    def proper_value
      value.blank? ? nil : value.to_i
    end

    def numeric_values_list
      [*value].map do |each_value|
        each_value.blank? ? nil : each_value.to_i
      end
    end

    def is(evaluate_on_value)
      evaluate_on_value == proper_value
    end

    def is_not(evaluate_on_value)
      !is(evaluate_on_value)
    end

    def in(evaluate_on_value)
      numeric_values_list.include?(evaluate_on_value)
    end

    def not_in(evaluate_on_value)
      !in_local(evaluate_on_value)
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
      contain_nil_value = [*value].include?(nil)
      is_none_condition = ''
      is_none_condition = null_check_query(q_operator == QUERY_OPERATOR[:in] ? contain_nil_value : !contain_nil_value) if insert_in_condition?(q_operator)

      [ " ( #{condition.db_column} #{q_operator} #{replacement_operator} #{is_none_condition} ) ", value ]
    end

    def insert_in_condition?(q_operator)
      q_operator == QUERY_OPERATOR[:in] || q_operator == QUERY_OPERATOR[:not_in]
    end

    def null_check_query(contain_nil_value)
      column_name = condition.db_column
      contain_nil_value ? (NULL_QUERY % {db_column:column_name}) : (NOT_NULL_QUERY % {db_column:column_name})
    end

    alias_method :in_local, :in
end
