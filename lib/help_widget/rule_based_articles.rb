class HelpWidget::RuleBasedArticles
  attr_accessor :value, :type, :order_by

  def initialize(rule_filter)
    @value = rule_filter[:value]
    @type = rule_filter[:type]
    @order_by = rule_filter[:order_by]
  end

  def fetch_articles(articles)
    return [] if value.blank?

    case type
    when HelpWidgetSuggestedArticleRule::FILTER_TYPE[:article]
      articles.where(id: value).sort_by { |e| value.index(e.id) }
    end
  end
end
