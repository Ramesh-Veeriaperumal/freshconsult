class Mobihelp::App < ActiveRecord::Base
  self.primary_key = :id
  include ApplicationHelper
  include  Mobihelp::AppSolutionsUtils
  include Cache::Memcache::Mobihelp::App
  include Cache::Memcache::Mobihelp::Solution
  
  self.table_name =  :mobihelp_apps

  concerned_with :associations, :solution_associations, :callbacks, :constants, :validations
  serialize :config, Hash
  attr_protected :account_id
  attr_accessor :category_ids
  
  belongs_to_account

  def push_notification_enabled?
    self.config[:push_notification].eql? 'true'
  end
  
  def category_ids_from_app_solutions
    app_solutions.pluck(:solution_category_meta_id)
  end
end
