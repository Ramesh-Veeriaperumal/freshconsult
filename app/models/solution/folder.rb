class Solution::Folder < ActiveRecord::Base
  
  validates_presence_of :name
  validates_uniqueness_of :name, :scope => :category_id
  
  belongs_to :category, :class_name => 'Solution::Category'
   set_table_name "solution_folders"
   
   has_many :articles, :class_name =>'Solution::Article' , :dependent => :destroy
   
   named_scope :alphabetical, :order => 'name ASC'
   
   def self.folders_for_category category_id
     
     self.find_by_category_id(category_id)
     
   end
   
 def self.find_all_folders(account)   
    self.find(:all).select { |a| a.account_id.eql?(account) }
  end
end
