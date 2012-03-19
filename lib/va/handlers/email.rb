class Va::Handlers::Email < Va::RuleHandler

  private
    def is(evaluate_on_value)
      evaluate_on_value && parse_email(evaluate_on_value).casecmp(value) == 0
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

    def parse_email(evaluate_on_value)
      if (evaluate_on_value =~ /.+<(.+)>/)
        evaluate_on_value = $1    
      end
      evaluate_on_value
    end

    def filter_query_is
      filter_query_contains
    end
    
    def filter_query_is_not
      filter_query_does_not_contain
    end
    
    def filter_query_contains
      [ "#{condition.db_column} like ?", "%#{value}%" ]
    end
    
    def filter_query_does_not_contain
      [ "#{condition.db_column} not like ?", "%#{value}%" ]
    end
end
  