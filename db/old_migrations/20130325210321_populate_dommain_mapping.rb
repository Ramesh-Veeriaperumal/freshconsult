class PopulateDommainMapping < ActiveRecord::Migration
  shard :none
  
  def self.up
  	execute("insert into domain_mappings(account_id,domain) select id,full_domain from accounts")
  	execute("insert into domain_mappings(account_id,portal_id,domain) select account_id,id,portal_url from portals where portal_url is not null and portal_url != ''")
  end

  def self.down
  	execute("delete from domain_mappings")
  end
end
