class Va::Handlers::TextArray < Va::RuleHandler

  private
    def is(evaluate_on_value)
      evaluate_on_value.each do |ev|
        return true if ev.casecmp(value) == 0
      end

      false
    end

    def is_not(evaluate_on_value)
      !is(evaluate_on_value)
    end

    def contains(evaluate_on_value)
      evaluate_the_op(:include?, evaluate_on_value)
    end

    def does_not_contain(evaluate_on_value)
      !contains(evaluate_on_value)
    end

    def starts_with(evaluate_on_value)
      evaluate_the_op(:starts_with?, evaluate_on_value)
    end

    def ends_with(evaluate_on_value)
      evaluate_the_op(:ends_with?, evaluate_on_value)
    end

    def evaluate_the_op(operator, evaluate_on_value)
      evaluate_on_value.each do |ev|
        return true if ev.downcase.send(operator, value.downcase)
      end
      false
    end
end
