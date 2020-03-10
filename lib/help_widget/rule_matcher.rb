class HelpWidget::RuleMatcher
  attr_accessor :condition, :request, :context

  def initialize(rule)
    @condition = rule['conditions'].first.symbolize_keys
  end

  def matched?(context: {})
    @context = context
    return false if evaluate_on.blank?

    value.send(operator, condition[:value])
  end

  def value
    evaluate_on[name].to_s
  end

  def evaluate_on
    context[HelpWidgetSuggestedArticleRule::EVALUATE_ON.key(condition[:evaluate_on])]
  end

  def name
    HelpWidgetSuggestedArticleRule::NAME_VALUE_MAPPING[condition[:name]]
  end

  def operator
    HelpWidgetSuggestedArticleRule::OPERATOR_VALUE_MAPPING[condition[:operator]]
  end
end
