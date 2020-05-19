class Solution::TemplateMapping < ActiveRecord::Base
  self.table_name = 'solution_template_mappings'

  attr_accessible :account_id, :used_cnt, :article_id, :template_id

  self.primary_key = :id

  belongs_to_account
  belongs_to :article, class_name: 'Solution::Article', foreign_key: 'article_id', inverse_of: :solution_template_mappings
  belongs_to :template, class_name: 'Solution::Template', foreign_key: 'template_id', inverse_of: :solution_template_mappings

  validates :account_id, presence: true
  validates :template_id, presence: true
end
