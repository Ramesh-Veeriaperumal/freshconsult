class Freshfone::BlacklistNumber < ActiveRecord::Base
	self.table_name =  :freshfone_blacklist_numbers
	belongs_to_account
end
