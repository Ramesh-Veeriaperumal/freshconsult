module HelpWidgets
  class SuggestedArticleRulesFilterValidation < FilterValidation
    attr_accessor :help_widget_id
    validates :help_widget_id, custom_numericality: { only_integer: true,
                                                      greater_than: 0,
                                                      ignore_string: :allow_string_param }, presence: true
  end
end
