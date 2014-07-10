class PopulateGlobalBlacklistedIp < ActiveRecord::Migration
  
  shard :none

  def self.up
  	execute("insert into global_blacklisted_ips (ip_list, created_at, updated_at)  values (NULL,now(), now())")
  end

end
