class Va::Handlers::Text < Va::RuleHandler

  private
    def query_value
      value.empty? ? nil : value
    end

    def is(evaluate_on_value)
      evaluate_on_value.to_s.casecmp(value) == 0
    end

    def is_not(evaluate_on_value)
      !is(evaluate_on_value)
    end

    def in(evaluate_on_value)
      value.include?(evaluate_on_value)
    end

    def contains(evaluate_on_value)
      evaluate_on_value && evaluate_on_value.downcase.include?(value.downcase)
    end

    def does_not_contain(evaluate_on_value)
      !contains(evaluate_on_value)
    end

    def starts_with(evaluate_on_value)
      evaluate_on_value && evaluate_on_value.downcase.starts_with?(value.downcase)
    end

    def ends_with(evaluate_on_value)
      evaluate_on_value && evaluate_on_value.downcase.ends_with?(value.downcase)
    end

    def filter_query_is
      construct_query (query_value ? '=' : 'is')
    end
    
    def filter_query_is_not
      if query_value
        [ "(#{condition.db_column} is NULL OR #{condition.db_column} != ?)", query_value ]
      else
        construct_query('is not')
      end
    end

    def construct_query(query_operator)
      [ "#{condition.db_column} #{query_operator} ?", query_value ]
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
end
