class CreateUserRoles < ActiveRecord::Migration
  def self.up
    create_table :user_roles, :id => false do |t|
      t.column :user_id, "bigint unsigned"
      t.column :role_id, "bigint unsigned"
      t.column :account_id, "bigint unsigned"
    end

    add_index :user_roles, :user_id
    add_index :user_roles, :role_id
    
  end

  def self.down
    drop_table :user_roles
  end
end