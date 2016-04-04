class Solution::CustomerFolder < ActiveRecord::Base

	self.table_name =  "solution_customer_folders"
  self.primary_key = :id

	before_validation :set_account_id


	belongs_to_account
	belongs_to :folder, :class_name => 'Solution::Folder'
	belongs_to :folder_meta, :class_name => 'Solution::FolderMeta'
	belongs_to :customer, :class_name => 'Company', :foreign_key => 'customer_id'
	belongs_to :account

	attr_protected :account_id , :folder_id

	validates_presence_of :customer_id

	delegate :update_search_index, :to => :folder, :allow_nil => true
	
	after_commit :update_search_index, on: :create

	def set_account_id
		self.account_id = customer.account_id
	end

	 

end
