class AddUserRoleToUser < ActiveRecord::Migration
  def self.up
    add_column :users, :user_role, :integer
  end

  def self.down
    remove_column :users, :user_role
  end
end
