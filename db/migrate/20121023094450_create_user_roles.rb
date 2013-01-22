class CreateUserRoles < ActiveRecord::Migration
  def self.up
    create_table :user_roles do |t|
      t.column :user_id, "bigint unsigned"
      t.column :role_id, "bigint unsigned"
      t.column :account_id, "bigint unsigned"

      t.timestamps
    end

    add_index :user_roles, [ :account_id, :user_id ]
    add_index :user_roles, [ :account_id, :role_id, :user_id ]
    
  end

  def self.down
    drop_table :user_roles
  end
end
