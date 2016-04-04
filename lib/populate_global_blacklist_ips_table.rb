module PopulateGlobalBlacklistIpsTable

	def self.create_default_record
		ActiveRecord::Base.connection.execute("insert into global_blacklisted_ips (ip_list, created_at, 
							updated_at) values ('--- []\n\n', now(), now())")
	end

end