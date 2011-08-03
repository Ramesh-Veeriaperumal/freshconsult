class Va::Handlers::Text < Va::RuleHandler

  private
    def is(evaluate_on_value)
      evaluate_on_value && evaluate_on_value.casecmp(value) == 0
    end

    def is_not(evaluate_on_value)
      !is(evaluate_on_value)
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
      [ "#{condition.db_column} = ?", value ]
    end
    
    def filter_query_is_not
      [ "#{condition.db_column} != ?", value ]
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
end
