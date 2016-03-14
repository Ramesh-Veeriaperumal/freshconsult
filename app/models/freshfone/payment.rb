class Freshfone::Payment < ActiveRecord::Base
  self.primary_key = :id
	self.table_name =  :freshfone_payments

	belongs_to_account
	attr_protected :account_id
end