class RemoveBgColorHeaderColorFromAccount < ActiveRecord::Migration
  def self.up
    remove_column :accounts, :bg_color
    remove_column :accounts, :header_color
  end

  def self.down
    add_column :accounts, :header_color, :string
    add_column :accounts, :bg_color, :string
  end
end
