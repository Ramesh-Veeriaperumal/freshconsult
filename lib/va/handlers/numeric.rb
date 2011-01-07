class Va::Handlers::Numeric < Va::Handlers::Text

  private
    def is(evaluate_on_value)
      evaluate_on_value == value
    end

end