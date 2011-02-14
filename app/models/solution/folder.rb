class Solution::Folder < ActiveRecord::Base
  
  belongs_to :category, :class_name => 'Solution::Category'
   set_table_name "solution_folders"
   
   has_many :articles, :class_name =>'Solution::Article'
   
   named_scope :alphabetical, :order => 'name ASC'
   
 def self.find_all_folders(account)   
    self.find(:all).select { |a| a.account_id.eql?(account) }
  end
end
