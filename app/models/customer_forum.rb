class CustomerForum < ActiveRecord::Base
	set_table_name "customer_forums"


	before_validation :set_account_id
	
	belongs_to :forum
	belongs_to :customer
	belongs_to :account

	attr_protected :account_id , :forum_id 

	validates_presence_of :customer_id

	protected 

	def set_account_id
		self.account_id = customer.account_id
	end

end
