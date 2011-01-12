class CreateProducts < ActiveRecord::Migration
  def self.up
    create_table :products do |t|
      t.string :name
      t.text :description
      t.string :to_email
      t.string :reply_email
      t.integer :solution_category_id
      t.integer :forum_category_id
      t.integer :account_id

      t.timestamps
    end
  end

  def self.down
    drop_table :products
  end
end
