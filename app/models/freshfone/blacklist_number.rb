class Freshfone::BlacklistNumber < ActiveRecord::Base
  self.primary_key = :id
	self.table_name =  :freshfone_blacklist_numbers
	belongs_to_account
end
