class Solution::Folder < ActiveRecord::Base
  
  belongs_to :account
   set_table_name "solution_folders"
   has_many :categories, :class_name =>'Helpdesk::Guide'
   
   
 def self.find_all_folders(account)   
    self.find(:all).select { |a| a.account_id.eql?(account) }
  end
end
