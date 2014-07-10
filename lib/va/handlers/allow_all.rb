class Va::Handlers::AllowAll < Va::RuleHandler
  def matches(evaluate_on)
    evaluate_on
  end
end
