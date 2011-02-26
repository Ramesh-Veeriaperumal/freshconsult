class Solution::Category < ActiveRecord::Base
  
  validates_presence_of :name,:account
  validates_uniqueness_of :name, :scope => :account_id
  
   belongs_to :account
   set_table_name "solution_categories"
   
   has_many :folders, :class_name =>'Solution::Folder' , :dependent => :destroy
   
   attr_accessible  :name,:description
   
end
