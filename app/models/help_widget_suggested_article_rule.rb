class HelpWidgetSuggestedArticleRule < ActiveRecord::Base
  include MemcacheKeys

  self.primary_key = :id
  belongs_to_account
  belongs_to :help_widget, class_name: 'HelpWidget', inverse_of: :help_widget_suggested_article_rules

  attr_accessible :help_widget_id, :conditions, :filter, :rule_operator
  acts_as_list scope: :help_widget
  default_scope order: :position

  serialize :conditions, Array
  serialize :filter, Hash

  validates :conditions, data_type: { rules: Array }, presence: true
  validates :filter, data_type: { rules: Hash }, presence: true

  after_commit :clear_cache

  private

    def clear_cache
      key = format(HELP_WIDGET_SUGGESTED_ARTICLE_RULES, account_id: account_id, help_widget_id: help_widget.id)
      delete_value_from_cache key
    end
end
