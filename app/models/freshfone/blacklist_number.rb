class Freshfone::BlacklistNumber < ActiveRecord::Base
	set_table_name :freshfone_blacklist_numbers
	belongs_to_account
end
