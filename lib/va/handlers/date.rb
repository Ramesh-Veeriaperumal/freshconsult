class Va::Handlers::Date < Va::RuleHandler

  private
    def date_value(val = value)
      val.to_date
    end

    def is(evaluated_on_value)
      date_value(evaluated_on_value) == date_value
    end

    def is_not(evaluated_on_value)
      !is(evaluated_on_value)
    end

    def greater_than(evaluated_on_value)
      date_value(evaluated_on_value) > date_value
    end

    def less_than(evaluated_on_value)
      date_value(evaluated_on_value) < date_value
    end
end
