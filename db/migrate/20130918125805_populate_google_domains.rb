class PopulateGoogleDomains < ActiveRecord::Migration
  
  shard :none
  
  def self.up
  	execute("insert into google_domains select id,google_domain from accounts")
  end

  def self.down
  	execute("delete from google_domains")
  end
end
