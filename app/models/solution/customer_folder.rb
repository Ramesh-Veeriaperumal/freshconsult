class Solution::CustomerFolder < ActiveRecord::Base

	set_table_name "solution_customer_folders"

	before_validation :set_account_id


	belongs_to :folder, :class_name => 'Solution::Folder'
	belongs_to :customer
	belongs_to :account

	attr_protected :account_id , :folder_id

	validates_presence_of :customer_id

	def set_account_id
		self.account_id = customer.account_id
	end

	 

end
