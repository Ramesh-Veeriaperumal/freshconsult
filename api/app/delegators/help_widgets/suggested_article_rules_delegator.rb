class HelpWidgets::SuggestedArticleRulesDelegator < BaseDelegator
  include ActiveRecord::Validations
  include HelpWidgets::SuggestedArticleRulesConstants

  attr_accessor :value, :filter_type, :help_widget

  validate :article_ids_count, if: -> { article_filter_type? }

  def initialize(help_widget, options = {})
    @value = options[:value]
    @filter_type = options[:type] || HelpWidgetSuggestedArticleRule::FILTER_TYPE[:article]
    @help_widget = help_widget
    @error_options ||= {}
  end

  private

    def article_filter_type?
      filter_type == HelpWidgetSuggestedArticleRule::FILTER_TYPE[:article]
    end

    def article_ids_count
      if value.size > ARTICLE_COUNT[:max] || value.empty?
        errors[:filter_value] << :too_long_too_short
        error_options.merge!(current_count: value.size, element_type: 'article',
                             min_count: ARTICLE_COUNT[:min], max_count: ARTICLE_COUNT[:max])
        return false
      end
      true
    end
end
