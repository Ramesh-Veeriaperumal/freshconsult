class AddPrivilegesToUser < ActiveRecord::Migration
  def self.up
    add_column :users, :privileges, :string
  end

  def self.down
    remove_column :users, :privileges
  end
end
