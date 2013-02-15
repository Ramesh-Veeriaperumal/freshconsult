class Va::Handlers::Symbol < Va::RuleHandler

  private
    def proper_value
      value.to_sym
    end
  
    def is(evaluate_on_value)
      evaluate_on_value == proper_value
    end
    
end