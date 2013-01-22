class CreateRoles < ActiveRecord::Migration
  def self.up
    create_table :roles do |t|
      t.string :name
      t.string :privileges
      t.text :description
      t.boolean :default_role, :default => false
      t.column :account_id, "bigint unsigned"
      
      t.timestamps
    end

    add_index :roles, [ :account_id, :name ]
    
  end

  def self.down
    drop_table :roles
  end
end
