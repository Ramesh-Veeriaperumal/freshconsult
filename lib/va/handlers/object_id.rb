class Va::Handlers::ObjectId < Va::RuleHandler

  private
    def proper_value
      value.blank? ? nil : value.to_i
    end

    def numeric_values_list
      [*value].map do |each_value|
        each_value.to_i if each_value.present?
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
      construct_in_query QUERY_OPERATOR[:in]
    end

    def filter_query_not_in
      construct_in_query QUERY_OPERATOR[:not_in]
    end

    def filter_query_is
      construct_is_query (proper_value ? QUERY_OPERATOR[:equal] : QUERY_OPERATOR[:is])
    end

    def filter_query_is_not
      construct_is_query (proper_value ? QUERY_OPERATOR[:not_equal] : QUERY_OPERATOR[:is_not])
    end

    #Checking 'proper_value' to avoid "column != null" condition as its invalid
    def filter_query_negation
      [ " #{condition.db_column} #{proper_value ? '!=' : 'is not'} ? OR #{condition.db_column} IS NULL ", proper_value ]
    end

    def construct_is_query(q_operator)
      [ "#{condition.db_column} #{q_operator} ?", proper_value ]
    end

    def construct_in_query(q_operator)
      value = numeric_values_list
      contain_nil_value = value.include?(nil) # check it has null value
      value.compact! # remove null value from the list/array

      # if there is any non-null value then please include IN or NOT IN query
      if value.length > 0
        # "IS NULL" query will be added depending on whether it is "IN" or "NOT IN" query.
        # In "IN" query, we will add "NULL query" if the list does have null value
        # In "NOT IN" query, we will add "NULL query" if the list does not have null value
        add_null_condition = (q_operator == QUERY_OPERATOR[:in] ? contain_nil_value : !contain_nil_value)
        none_value_query = add_null_condition ? "OR #{null_query}" : ""
        query = ["#{condition.db_column} #{q_operator} (?) #{none_value_query}", value]
      else
        # if list have only null value then we don't need to send "IN" or "NOT IN" query
        query = (q_operator == QUERY_OPERATOR[:in]) ? [null_query] : [null_query(:not_null)]
      end
      query
    end

    alias_method :in_local, :in
end

# NOTE: PLEASE DON'T DELETE THE BELOW COMMENT

=begin
query = in           nonNullValue > 0 => if contain_null "OR col IS NULL" else ""          nonNullValue == 0 =>  "col IS NULL"
query = not_in       nonNullValue > 0 => if contain_null "" else "OR col IS NULL"          nonNullValue == 0 =>  "col IS NOT NULL"
=end
