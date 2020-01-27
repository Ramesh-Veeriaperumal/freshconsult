class HelpWidgetSuggestedArticleRule < ActiveRecord::Base
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
end
