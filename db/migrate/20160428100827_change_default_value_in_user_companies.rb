class ChangeDefaultValueInUserCompanies < ActiveRecord::Migration
  
  shard :all

  def self.up
    Lhm.change_table :user_companies, :atomic_switch => true do |m|
      m.change_column :default, "tinyint(1) DEFAULT 0"
      m.change_column :client_manager, "tinyint(1) DEFAULT 0"
    end
  end
end
