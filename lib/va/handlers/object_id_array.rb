class Va::Handlers::ObjectIdArray < Va::RuleHandler

  def in(evaluate_on_value, &block)
    return true if (evaluate_on_value.blank? && !block_given?) && (value && value[0].blank?)
    evaluate_on_value = block.call([value]) if block_given?
    !(evaluate_on_value & [*value].map(&:to_i)).empty?
  end

  private

    def not_in(evaluate_on_value, &block)
      !self.in(evaluate_on_value, &block)
    end

    def and(evaluate_on_value)
      return true if (evaluate_on_value.blank? and (value and value[0].blank?))
      (evaluate_on_value & [*value].map(&:to_i)).size == [*value].size
    end
end
