class AddExtraStringColumnsToUsers < ActiveRecord::Migration
  shard :none
  def self.up
  	add_column :users, :string_uc02, :string
  	add_column :users, :string_uc03, :string
  	add_column :users, :string_uc04, :string
  	add_column :users, :string_uc05, :string
  	add_column :users, :string_uc06, :string
  end

  def self.down
  	remove_column :users, :string_uc02
  	remove_column :users, :string_uc03
  	remove_column :users, :string_uc04
  	remove_column :users, :string_uc05
  	remove_column :users, :string_uc06
  end
end
