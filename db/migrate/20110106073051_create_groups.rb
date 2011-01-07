class CreateGroups < ActiveRecord::Migration
  def self.up
    create_table :groups do |t|
      t.string :name
      t.text :description
      t.integer :account_id
      t.boolean :email_on_assign
      t.integer :escalate_to
      t.integer :assign_time

      t.timestamps
    end
  end

  def self.down
    drop_table :groups
  end
end
