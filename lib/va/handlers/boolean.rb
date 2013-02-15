class Va::Handlers::Boolean < Va::RuleHandler

  private

    def boolean_value
      value.to_bool
    end

    def is(evaluate_on_value)
      boolean_value == evaluate_on_value
    end

    def selected(evaluate_on_value)
      evaluate_on_value
    end

    def not_selected(evaluate_on_value)
      !selected(evaluate_on_value)
    end
    
    def filter_query_selected
      [ "#{condition.db_column} = 1" ]
    end
    
    def filter_query_not_selected
      [ "#{condition.db_column} != 1" ]
    end

end
