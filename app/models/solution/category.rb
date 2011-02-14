class Solution::Category < ActiveRecord::Base
   belongs_to :account
   set_table_name "solution_categories"
   
   has_many :folders, :class_name =>'Solution::Folder'
end
