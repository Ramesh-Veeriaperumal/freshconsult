class Freshfone::Payment < ActiveRecord::Base
  self.primary_key = :id
	self.table_name =  :freshfone_payments

	belongs_to_account
	attr_protected :account_id

	STATUS_MESSAGE = [:promotional, :refunded]
	scope :not_promotional_or_refunded_credit,
		where("status_message IS NULL OR STATUS_MESSAGE NOT IN (?)", STATUS_MESSAGE)
end