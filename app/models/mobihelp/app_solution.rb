class Mobihelp::AppSolution < ActiveRecord::Base
  include Cache::Memcache::Mobihelp::Solution

  self.table_name = :mobihelp_app_solutions

  belongs_to_account
  belongs_to :app, :class_name => 'Mobihelp::App'
  belongs_to :solution_category, :class_name => 'Solution::Category', :foreign_key => :category_id
  belongs_to :solution_category_meta, :class_name => 'Solution::CategoryMeta'

  attr_protected :account_id

  after_commit :clear_last_updated_time_cache

  private
    def clear_last_updated_time_cache
      clear_last_updated_time(app_id)
    end
end
