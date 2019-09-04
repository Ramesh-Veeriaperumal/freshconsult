class HelpWidgetSolutionCategory < ActiveRecord::Base
  self.primary_key = :id
  belongs_to_account
  belongs_to :help_widget, class_name: 'HelpWidget', inverse_of: :help_widget_solution_categories
  belongs_to :solution_category_meta, class_name: 'Solution::CategoryMeta', foreign_key: :solution_category_meta_id, inverse_of: :help_widget_solution_categories

  attr_accessible :help_widget_id, :solution_category_meta_id
  acts_as_list scope: :help_widget
end
