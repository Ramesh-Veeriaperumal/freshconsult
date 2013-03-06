class AddDefaultValueForPrivilegesInUsers < ActiveRecord::Migration
  def self.up
    change_column :users, :privileges, :string, :default => "0"
    execute("update users set privileges = '0' where privileges is null")
  end

  def self.down
    execute("update users set privileges = null where privileges = '0'")
    change_column :users, :privileges, :string, :default => nil
  end
end
