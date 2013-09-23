class PopulateGoogleDomains < ActiveRecord::Migration
  
  shard :none
  
  def self.up
  	execute("insert into google_domains select id,google_domain from accounts where google_domain != 'NULL' and google_domain != ''")
  end

  def self.down
  	execute("delete from google_domains")
  end
end
