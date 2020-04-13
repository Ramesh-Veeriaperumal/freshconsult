module HelpWidgets
  module SuggestedArticleRulesConstants
    FEATURES = [:help_widget, :help_widget_article_customisation].freeze
    LIST_FIELDS = [:help_widget_id].freeze
    CREATE_FIELDS = [{ conditions: [:evaluate_on, :name, :operator, :value] },
                     { filter: [:type, :order_by, :value] },
                     :rule_operator, :position].freeze
    DEFAULT_RULE_LIMIT = 100
    ARTICLE_COUNT = {
      min: 1,
      max: 5
    }.freeze
    VALIDATION_CLASS = 'HelpWidgets::SuggestedArticleRulesValidation'.freeze
    DELEGATOR_CLASS = 'HelpWidgets::SuggestedArticleRulesDelegator'.freeze
  end
end
