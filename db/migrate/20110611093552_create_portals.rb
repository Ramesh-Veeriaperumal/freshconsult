class CreatePortals < ActiveRecord::Migration
  def self.up
    create_table :portals do |t|
      t.string :name
      t.integer :product_id,          :limit => 8
      t.integer :account_id,          :limit => 8
      t.string :portal_url
      t.text :preferences

      t.timestamps
    end
    
    add_index :portals, [:account_id, :portal_url], :name => "index_portals_on_account_id_and_portal_url"
    add_index :portals, [:account_id, :product_id], :name => "index_portals_on_account_id_and_product_id"
    add_index :portals, [:portal_url], :name => "index_portals_on_portal_url"
  end

  def self.down
    drop_table :portals
  end
end
