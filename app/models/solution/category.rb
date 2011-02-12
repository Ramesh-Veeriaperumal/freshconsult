class Solution::Category < ActiveRecord::Base
   belongs_to :account
   set_table_name "solution_categories"
end
