class CreatePortalForumCategories < ActiveRecord::Migration
  shard :all
  def self.up
  	create_table :portal_forum_categories do |t|
      t.column :portal_id, "bigint unsigned"
      t.column :forum_category_id, "bigint unsigned"
      t.column :account_id, "bigint unsigned"
      t.integer :position
    end

    add_index :portal_forum_categories, [:account_id, :portal_id]
    add_index :portal_forum_categories, [:portal_id, :forum_category_id]
  end

  def self.down
  	drop_table :portal_forum_categories
  end
end
