class Va::Handlers::Text < Va::RuleHandler

  private
    def query_value
      value.empty? ? nil : value
    end

    def values_in_downcase
      [*value].map(&:downcase)
    end
    def is(evaluate_on_value)
      evaluate_on_value.to_s.casecmp(value) == 0
    end

    def is_not(evaluate_on_value)
      !is(evaluate_on_value)
    end

    def in(evaluate_on_value)
      evaluate_on_value ||= ""
      values_in_downcase.include?(evaluate_on_value.downcase)
    end

    def not_in(evaluate_on_value)
      !in_local evaluate_on_value
    end

    def contains(evaluate_on_value)
      evaluate_on_value && value.present? && evaluate_on_value.downcase.include?(value.downcase)
    end

    def does_not_contain(evaluate_on_value)
      evaluate_on_value && value.present? && !evaluate_on_value.downcase.include?(value.downcase)
    end

    def starts_with(evaluate_on_value)
      evaluate_on_value && value.present? && evaluate_on_value.downcase.starts_with?(value.downcase)
    end

    def ends_with(evaluate_on_value)
      evaluate_on_value && value.present? && evaluate_on_value.downcase.ends_with?(value.downcase)
    end

    def filter_query_is
      construct_query (query_value ? QUERY_OPERATOR[:equal] : QUERY_OPERATOR[:is])
    end
    
    def filter_query_is_not
      construct_query (query_value ? QUERY_OPERATOR[:not_equal] : QUERY_OPERATOR[:is_not])
    end

    def filter_query_in
      construct_query QUERY_OPERATOR[:in], values_in_downcase, '(?)'
    end

    def filter_query_not_in
      construct_query QUERY_OPERATOR[:not_in], values_in_downcase, '(?)'
    end

    def construct_query(query_operator, value = query_value, replacement_operator = '?')
      is_none_condition = (query_operator == QUERY_OPERATOR[:in] and [*value].include?("")) ? "OR #{condition.db_column} IS NULL" : ""
      [ " ( #{condition.db_column} #{query_operator} #{replacement_operator} #{is_none_condition} ) ", value ]
    end
    
    def filter_query_contains
      [ "#{condition.db_column} like ?", "%#{value}%" ]
    end
    
    def filter_query_does_not_contain
      [ "#{condition.db_column} not like ?", "%#{value}%" ]
    end
    
    def filter_query_starts_with
      [ "#{condition.db_column} like ?", "#{value}%" ]
    end
    
    def filter_query_ends_with
      [ "#{condition.db_column} like ?", "%#{value}" ]
    end

    def filter_query_negation(field_key=nil,field_values=nil)
      if field_key.nil?
        [ "#{condition.db_column} IS NULL OR #{condition.db_column} != ?", value ]
      else
        ["flexifields.#{FlexifieldDefEntry.ticket_db_column field_key} IS NULL OR flexifields.#{FlexifieldDefEntry.ticket_db_column field_key} != ?", field_value.to_s]
      end
    end

    alias_method :in_local, :in
end
