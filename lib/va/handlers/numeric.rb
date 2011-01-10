class Va::Handlers::Numeric < Va::RuleHandler

  private
    def numeric_value
      value.to_i
    end
  
    def is(evaluate_on_value)
      puts "IN Va::Handlers::Numeric evaluate_on_value is #{evaluate_on_value}"
      puts "IN Va::Handlers::Numeric numeric_value is #{numeric_value}"
      evaluate_on_value == numeric_value
    end

    def is_not(evaluate_on_value)
      !is(evaluate_on_value)
    end

end