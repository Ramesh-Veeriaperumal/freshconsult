class AddClientManagerToUserCompanies < ActiveRecord::Migration

  shard :all

  def self.up
    Lhm.change_table :user_companies, :atomic_switch => true do |m|
      m.add_column :client_manager, :boolean
    end
  end

  def self.down
    Lhm.change_table :user_companies, :atomic_switch => true do |m|
      m.remove_column :client_manager, :boolean
    end
  end
end
