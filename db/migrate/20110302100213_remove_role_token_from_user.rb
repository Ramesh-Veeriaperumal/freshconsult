class RemoveRoleTokenFromUser < ActiveRecord::Migration
  def self.up
    remove_column :users, :role_token
  end

  def self.down
    add_column :users, :role_token, :string
  end
end
