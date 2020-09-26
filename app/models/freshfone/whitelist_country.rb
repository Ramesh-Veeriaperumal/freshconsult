class Freshfone::WhitelistCountry < ActiveRecord::Base
	self.table_name = :freshfone_whitelist_countries
	belongs_to_account
end
