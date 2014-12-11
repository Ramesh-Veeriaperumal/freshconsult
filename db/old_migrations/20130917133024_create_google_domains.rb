class CreateGoogleDomains < ActiveRecord::Migration
  shard :none    
  
  def self.up
  	create_table :google_domains, {:primary_key => :account_id } do |t|
      t.string  :domain,:null => false, :unique => true
    end
    add_index :google_domains, [:domain], :unique => true
  end

  def self.down
  	drop_table :google_domains
  end
end
