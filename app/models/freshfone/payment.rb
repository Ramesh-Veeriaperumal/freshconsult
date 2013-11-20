class Freshfone::Payment < ActiveRecord::Base
	set_table_name :freshfone_payments
	belongs_to_account
	attr_protected :account_id
end