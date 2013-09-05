class AddParentIdColumnToUsers < ActiveRecord::Migration
  shard :none
  def self.up
  	add_column :users, :string_uc02, :string
  end

  def self.down
  	remove_column :users, :string_uc02, :string
  end
end
