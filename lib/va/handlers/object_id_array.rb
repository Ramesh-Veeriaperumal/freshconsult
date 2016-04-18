class Va::Handlers::ObjectIdArray < Va::RuleHandler

    def in(evaluate_on_value)
      return true if (evaluate_on_value.blank? and (value and value[0].blank?))
      (evaluate_on_value & [*value].map(&:to_i)).size > 0
    end

  private

    def not_in(evaluate_on_value)
      !(self.in(evaluate_on_value))
    end

    def and(evaluate_on_value)
      return true if (evaluate_on_value.blank? and (value and value[0].blank?))
      (evaluate_on_value & [*value].map(&:to_i)).size == [*value].size
    end
end
