class CreatePortalPages < ActiveRecord::Migration
  def self.up
    create_table :portal_pages do |t|
      t.integer :template_id, :limit => 8, :null => false
      t.integer :account_id, :limit => 8, :null => false
      t.integer :page_type, :null => false
      t.text :content
      t.timestamps
    end
  end

  def self.down
    drop_table :portal_pages
  end
end
