class Solution::CustomerFolder < ActiveRecord::Base

	set_table_name "solution_customer_folders"

	before_validation :set_account_id


	belongs_to_account
	belongs_to :folder, :class_name => 'Solution::Folder'
	belongs_to :customer
	belongs_to :account

	attr_protected :account_id , :folder_id

	validates_presence_of :customer_id

	delegate :update_search_index, :to => :folder, :allow_nil => true
	
	after_commit_on_create :update_search_index

	def set_account_id
		self.account_id = customer.account_id
	end

	 

end
