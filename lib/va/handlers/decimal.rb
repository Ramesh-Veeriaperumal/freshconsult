class Va::Handlers::Decimal < Va::Handlers::Numeric

  private
    
    def numeric_value
      value.to_f
    end

    def in(evaluate_on_value)
      value.map(&:to_f).include?(evaluate_on_value)
    end
    
end