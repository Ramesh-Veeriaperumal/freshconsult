class CreatePortalSolutionCategories < ActiveRecord::Migration
  shard :all
  def self.up
  	create_table :portal_solution_categories do |t|
      t.column :portal_id, "bigint unsigned"
      t.column :solution_category_id, "bigint unsigned"
      t.column :account_id, "bigint unsigned"
      t.integer :position
    end

    add_index :portal_solution_categories, [:account_id, :portal_id]
  end

  def self.down
  	drop_table :portal_solution_categories
  end
end