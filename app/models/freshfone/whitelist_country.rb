class Freshfone::WhitelistCountry < ActiveRecord::Base
	set_table_name :freshfone_whitelist_countries
	belongs_to_account
end
