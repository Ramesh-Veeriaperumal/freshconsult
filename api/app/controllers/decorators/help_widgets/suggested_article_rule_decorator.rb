module HelpWidgets
  class SuggestedArticleRuleDecorator < ApiDecorator
    delegate :id, :conditions, :rule_operator, :filter, :position, to: :record

    def to_hash
      {
        id: id,
        conditions: conditions,
        rule_operator: rule_operator,
        filter: filter,
        position: position
      }
    end
  end
end
