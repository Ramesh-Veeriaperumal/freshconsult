class CreateDomainMapping < ActiveRecord::Migration
  
  shard :none    

  def self.up
  	create_table :domain_mappings do |t|
  	  t.column  :account_id, "bigint unsigned", :null => false
  	  t.column  :portal_id, "bigint unsigned"
      t.string  :domain,:null => false
    end
    add_index :domain_mappings, [:account_id, :portal_id], :unique => true
    add_index :domain_mappings,:domain, :unique => true
  end

  def self.down
  	drop_table :domain_mappings
  end
end
