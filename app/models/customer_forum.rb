class CustomerForum < ActiveRecord::Base
	self.table_name =  "customer_forums"
  self.primary_key = :id


	before_validation :set_account_id
	
	belongs_to :forum
	belongs_to :customer, :class_name => 'Company', :foreign_key => 'customer_id'
	belongs_to :account

	attr_protected :account_id , :forum_id 

	validates :customer, :presence => true

	delegate :update_search_index, :to => :forum, :allow_nil => true
	
	after_commit :update_search_index, on: :create

	protected 

	def set_account_id
		self.account_id = customer.account_id if customer
	end

end
